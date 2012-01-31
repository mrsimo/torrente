require "rubygems"
require "bundler/setup"

require 'dropbox_sdk'
require 'tempfile'

APP_KEY     = '1e26nxsswjrjymt'
APP_SECRET  = '36syf1y8okbxqyx'
ACCESS_TYPE = :dropbox
CONFIG_FILE = File.expand_path("~/.torrente")

class Torrente
  attr_accessor :path, :client, :session

  def initialize(path)
    @path = path

    @session = if File.exists?(CONFIG_FILE)
      DropboxSession.deserialize(File.read(CONFIG_FILE))
    else
      manually_authorize
    end

    @client = DropboxClient.new(@session, ACCESS_TYPE)
  end

  def run!
    puts "#{Time.now}:Running torrente!"
    client.metadata(path)["contents"].each do |file|
      contents = client.get_file(file["path"])

      if file["mime_type"] =~ /torrent/
        tempfile = Tempfile.new("torrente")
        tempfile.write contents
        tempfile.close

        puts ":: Adding #{file["path"]} to transmission"
        system "transmission-remote -a #{tempfile.path}"

        puts ":: Deleting #{file["path"]} to transmission"
        client.file_delete(file["path"])
      else
        contents.split("\n").each do |magnet|
          puts ":: Adding a magnett to transmission"
          system "transmission-remote -a '#{magnet.strip}'"
        end
        puts ":: Deleting #{file["path"]} to transmission"
        client.file_delete(file["path"])
      end
    end
  end

  private

  def manually_authorize
    session = DropboxSession.new(APP_KEY, APP_SECRET)
    session.get_request_token

    puts "Please visit this website and press the 'Allow' button, then hit 'Enter' here."
    puts session.get_authorize_url

    puts "Press intro when you've accepted."
    gets

    session.get_access_token

    if session.authorized?
      File.open(CONFIG_FILE,"w+"){ |f| f.write(session.serialize) }
      session
    else
      puts "Looks like you didn't :("
      exit 1
    end
  end
end

Torrente.new(ENV["TORRENTS"] || "torrents-casa").run!

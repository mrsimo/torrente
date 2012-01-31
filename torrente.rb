require "rubygems"
require "bundler/setup"

require 'dropbox_sdk'
require 'tempfile'
require 'logger'

APP_KEY     = '1e26nxsswjrjymt'
APP_SECRET  = '36syf1y8okbxqyx'
ACCESS_TYPE = :dropbox
CONFIG_FILE = File.expand_path("~/.torrente")
LOG         = File.expand_path("~/torrente.log")

class Torrente
  attr_accessor :path, :client, :session, :logger

  def initialize(path)
    @path = path
    @logger = Logger.new(LOG)

    @session = if File.exists?(CONFIG_FILE)
      DropboxSession.deserialize(File.read(CONFIG_FILE))
    else
      manually_authorize
    end

    @client = DropboxClient.new(@session, ACCESS_TYPE)
  end

  def run!
    logger.info "#{Time.now}:Running torrente!"
    client.metadata(path)["contents"].each do |file|
      contents = client.get_file(file["path"])

      if file["mime_type"] =~ /torrent/
        tempfile = Tempfile.new("torrente")
        tempfile.write contents
        tempfile.close

        logger.info "Adding #{file["path"]} to transmission"
        system "transmission-remote -a #{tempfile.path}"

        logger.info "Deleting #{file["path"]} to transmission"
        client.file_delete(file["path"])
      else
        contents.split("\n").each do |magnet|
          if magnet.strip != ""
            logger.info "Adding a magnett to transmission"
            system "transmission-remote -a '#{magnet.strip}'"
          end
        end
        logger.info "Deleting #{file["path"]} to transmission"
        client.file_delete(file["path"])
      end
    end
  end

  private

  def manually_authorize
    session = DropboxSession.new(APP_KEY, APP_SECRET)
    session.get_request_token

    logger.info "Please visit this website and press the 'Allow' button, then hit 'Enter' here."
    logger.info session.get_authorize_url

    logger.info "Press intro when you've accepted."
    gets

    session.get_access_token

    if session.authorized?
      File.open(CONFIG_FILE,"w+"){ |f| f.write(session.serialize) }
      session
    else
      logger.info "Looks like you didn't :("
      exit 1
    end
  end
end

Torrente.new(ENV["TORRENTS"] || "torrents-casa").run!

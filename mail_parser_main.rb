require 'yaml'
require 'mail'
require_relative '../commonutils/exLogger.rb'
require_relative './mail_parser_core.rb'
require_relative './mail_parser_concrete.rb'
require_relative './mail_parser_analyzer.rb'

#set parsing mode.
include LoggerConf
yml = YAML.load_file('mail_parser.yml')
$Log       = Logger.new( yml['config']['logfile'], 'daily' )
$Log.level = LoggerConf.level (yml['config']['loglevel'])

case yml['config']['mode']
    when "eml"
	$Log.info "parse eml mails."
	p "parse eml mails"
        mailDirector= ParsingDirector.new(EmlReader.new(yml['config']['eml_mail_path'],OplogMailAnalyzer.new) )
    when "pop3"
	$Log.info "parse emails from pop server"
	p "parse emails from pop server"
        mailDirector= ParsingDirector.new(POP3Reader.new(yml['credential'],OplogMailAnalyzer.new)) 
    when "imap"

    else
end
#parse e-mails and convert events formatted with hash list.
mailDirector.do

#output events.
mailDirector.write_to "oplog.mail"


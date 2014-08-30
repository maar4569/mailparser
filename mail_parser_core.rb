require 'yaml'
require 'mail'
require_relative '../commonutils/exLogger.rb'
require_relative './mail_parser_analyzer.rb'
#director
class ParsingDirector
    def initialize(parserBuilder)
        @mail_parser =  parserBuilder
    end
    def do
        @events = @mail_parser.retrieve_mail
    end
    def write_to(filename)
        begin
            File.open( filename ,"w") do | file |
                @events.each do | event | file.puts "#{event[0]},#{event[1]}" end
            end
        rescue
            p "excepion #{self.class.name}.#{__method__}"
            p $!
        end
    end
end
#builder interface
class ReaderBuilder
    def initialize
        raise "called abstract method(initialize)"   
    end
    def retrieve_mail
        raise "called abstract method(retrieve_mail)"
    end
end
#mail analyzer
class MailAnalyzer
  include MailAnalysys
  def initialize
  end
  def load(mail)
      @mail = MailAnalysys.mail_to_hash( mail ) #hashed mail
  end
  def parse_mail
      raise "abstratd method"
      $Log.fatal "raise abstracted method(#{__method__}. please overwrite)"
  end
end

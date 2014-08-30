require_relative '../logger/exlogger.rb'
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

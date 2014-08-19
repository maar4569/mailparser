class ParsingDirector
    def initialize(parserBuilder)
        @mail_parser =  parserBuilder
    end
    def do
      @mail_parser.retrieve_mail
    end
end
#builder interface
class ParserBuilder
    def initialize
        raise "called abstract method(initialize)"   
    end
    def retrieve_mail
        raise "called abstract method(retrieve_mail)"
    end
end
#concreate builder
class EmlParser < ParserBuilder
    def initialize(eml_dir)
        @emr_dir = eml_dir
    end
    def retrieve_mail
        #directory_loop
	#sample
           mailObject = Hash.new
	   mailObject[:mail_to]="aaa@example.com"
	   mailObject[:mail_from]="bbb@example.com"
	   mailObject[:subject]="thank you"
	   mailObject[:mail_timestamp]="2014/08/20 23:59:59"
	   mailObject[:log_timestamp]="2014/12/31 00:00:00"
	   mailObject[:mail_type] = "smllw"
	   mailObject[:body] = "test:hello test2:bye"
	#sample
	#mailObject = "smllw"	
	mlpsr = OplogMailParser.new(mailObject)
	events = mlpsr.parse_mail
        #sample
	p "events====== #{events[:log_timestamp]}"
	#sample
    end
end
class POP3Parser < ParserBuilder
   def initialize(credential)
       @mailserver = ""
       @port       = ""
       @username   = ""
       @password   = ""
       @isssl      = false
   end
   def retrieve_mail
       #find option(count) loop
       mlpsr = OplogMailParser.new(mailObject)
       mlpsr.parse_mail
   end
end

class OplogMailParser
  attr_reader   :mail_to , :mail_from , :subject, :mail_type, :bodyparser ,:mail_timestamp,:log_timestamp
  def initialize(mail)
      @mailObject = mail
      p "mail->#{mail}"
  end
  def getMailTypeFromSubject(subject)
      begin
          p "mailtype is #{@mailObject[:mail_type]}"
      rescue
          p "excepion #{self.class.name}.#{__method__}"
	  p $!
      end
      return @mailObject[:mail_type]
  end
  def setParser(&bodyparser)
    @bodyparser = bodyparser
  end
  def parse_mail
      begin
	  #parse body
          @mail_type = getMailTypeFromSubject @subject
          case @mail_type
              when "bk_del"
                  self.setParser(&BK_DEL_MAIL_PARSER)
              when "smllw"
                  self.setParser(&LW_MAIL_PARSER)
              when "WP"
                  self.setParser(&WP_MAIL_PARSER)
              else
                   p "we does not scan this mail."
          end
          events = @bodyparser.call(@mailObject)
      rescue
         p "excepion #{self.class.name}.#{__method__}"
	 p $!
      end
    return events
  end
  def toJson
    return "returned JSON!!!!"
  end
  def toCsv
      csvrec=""
      case @mail_type
          when "bk_del"
          when "smllw"
          when "WP"		  
              csvrec = "#{@mail_timestamp.to_s},mail_to=#{@mail_to.to_s} mail_from=#{@mail_from.to_s} subject=#{@subject.to_s} #{@body.to_s}"
          else
      end
  end
  #startegy for parsing mail body
  BK_DEL_MAIL_PARSER = lambda do | context |
      events = Hash.new
      return events
  end

  LW_MAIL_PARSER = lambda do | context |
      events = Hash.new
      events[context[:mail_timestamp]] = "mail_from=\"#{context[:mail_from]}\" mail_to=\"#{context[:mail_to]}\"  subject=\"#{context[:subject]}\"  mail_type=#{context[:mail_type]} body=\"#{context[:body]}\""
				
      return events
  end
  WP_MAIL_PARSER = lambda do | context |
      p "parse body: #{context}"
      events = Hash.new
      return events
  end
end
#-----------------------------------
#1.set parse mode file(eml)? or POP3?
parse_mode ="eml" # or pop3

case parse_mode
    when "eml"
        eml_dir=""
        mailDirector= ParsingDirector.new(EmlParser.new(eml_dir))
    when "pop3"
	credential = ""
        mailDirector= ParsingDirector.new(POP3Parser.new(credential))
    when "imap"

    else
end

mailDirector.do


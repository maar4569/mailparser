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
	mailObject = "smllw"	
        mlpsr = OplogMailParser.new(mailObject)
	mlpsr.parse_mail
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
  attr_reader   :mail_to , :mail_from , :subject, :mail_type, :bodyparser ,:body ,:mail_timestamp,:log_timestamp
  def initialize(mail)
    @mail_to     = ""
    @mail_from   = ""
    @subject     = ""
    @body        = "hello body"
    @attachments = ""
    @mail_timestamp = ""
    @log_timestamp = ""
    @mail_type = mail
  end
  def getMailTypeFromSubject(subject)
  
  end
  def setParser(&bodyparser)
    @bodyparser = bodyparser
  end
  def parse_mail
    #begin
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
      ret = @bodyparser.call(self)
      p "#{ret} (from call)"
      @body = @body + " " + ret
    #rescue
     
    #end
    return ret
  end
  def getJson
    return "returned JSON!!!!"
  end

  #startegy for parsing mail body
  BK_DEL_MAIL_PARSER = lambda do | context |
      p "mailbody ->#{context.body} #{context.mail_type}"
  end

  LW_MAIL_PARSER = lambda do | context |
      p "mailbody ->#{context.body} #{context.mail_type}"
      return "smllw_body"
  end
  WP_MAIL_PARSER = lambda do | context |
      p "mailbody ->#{context.body} #{context.mail_type}"
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


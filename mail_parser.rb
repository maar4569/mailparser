require 'yaml'
require 'mail'
class ParsingDirector
    def initialize(parserBuilder)
        @mail_parser =  parserBuilder
    end
    def do
      @mail_parser.retrieve_mail
    end
    def write_to(filename)
      @mail_parser.write_to filename
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
    def write_to(filename)
	raise "called abstract method(write_to)"
    end
end
#concreate builder
class EmlParser < ParserBuilder
    def initialize(eml_dir)
        @eml_dir = eml_dir
	@events  = Hash.new
    end
    def retrieve_mail
        p "#{self.class.name}.#{__method__} from #{@eml_dir}"
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
	mlpsr = OplogMailParser.new(mailObject)
        parsed_events = mlpsr.parse_mail
	@events.merge parsed_events
    end
    def write_to(filename)
	p @events
    end
end
class POP3Parser < ParserBuilder
   def initialize(credential)
       @credential = credential
       @events     = Hash.new
   end
   def retrieve_mail
       cred = @credential
       begin
	   #authentication
	   Mail.defaults do
	       p "access to #{cred['hostname']} #{cred['port']}"
               retriever_method :pop3, :address    => cred['hostname'],
		                       :port       => cred['port'],
				       :user_name  => cred['username'],
	                               :password   => cred['password'],
				       :enable_ssl => cred['enable_ssl']
           end
	   #retrieve
	   mails = Mail.find(:what => :first, :count => 5, :order => :desc)
	   p "downloaded  #{mails.length} mail(s)"
	   if mails.length > 0 then
	       mails.each do | mail |
		   #MAIL_DUMP.call mail
	           mail2 = MAIL_TO_HASH.call mail
                   mlpsr = OplogMailParser.new(mail2)
                   parsed_events = mlpsr.parse_mail
		   if parsed_events != nil then 
	               @events.merge parsed_events
		   end
               end
	   end
           p "created #{@events.size} events."
       rescue
          p "excepion #{self.class.name}.#{__method__}"
	  p $!
       end
   end
   MAIL_DUMP = lambda do | mail |
       p "call lambda MAIL_DUMP"
       p "from #{mail.from}"
       p "to #{mail.to}"
       p "subject #{mail.subject}"
       p "date #{mail.date.to_s}"
       p "body #{mail.body}"
       #p "body(d) #{mail.body.decoded}"
   end
   MAIL_TO_HASH = lambda do | mail |
       tmp_body = mail.body
       if mail.multipart? == true then 
         tmp_body = mail.text_part.decoded 
       end
       listed_mail = [[:mail_from,mail.from],
	             [:mail_to,mail.from],
		     [:subject,mail.subject],
		     [:date,mail.date.to_s],
		     [:body,tmp_body]
                    ]
       hashed_mail = Hash[*listed_mail.flatten(1)]
       p "hased mail-> #{hashed_mail}"
       return hashed_mail
   end
   def write_to(filename)
       @events	   
   end
end

class OplogMailParser
  #attr_reader   :mail_to , :mail_from , :subject, :mail_type, :bodyparser ,:mail_timestamp,:log_timestamp
  def initialize(mail)
      @mail = mail #hased mail
  end
  def getMailTypeFromSubject(subject)
      regex_ptns = {"smllw"=>"^Notification from SML",
                    "bk_del"=>"^\\[SML\\]\\[(Backup|Delete)\\] (Success|Fatal).+ ",
                    "wp"=>"^\\[SML Server Status! (Warning!|fiz)\\]"}
      begin
          #regex
	  regex_ptns.each do | k,v |
            test = Regexp.compile(v, Regexp::IGNORECASE)
	    if test.match(subject) != nil then
	      @mail[:mail_type] = k
	      break;
	    end
          end
          p "mailtype is #{@mail[:mail_type]}"
      rescue
          p "excepion #{self.class.name}.#{__method__}"
	  p $!
      end
      return @mail[:mail_type]
  end
  def setParser(&bodyparser)
    @bodyparser = bodyparser
  end
  def parse_mail
      begin
          #parse header
	      #
	  #parse body
          @mail_type = getMailTypeFromSubject @mail[:subject]
          case @mail_type
              when "bk_del"
                  self.setParser(&BK_DEL_MAIL_PARSER)
              when "smllw"
                  self.setParser(&LW_MAIL_PARSER)
              when "wp"
                  self.setParser(&WP_MAIL_PARSER)
              else
                   p "we does not scan this mail."
		   return nil
          end
          events = @bodyparser.call(@mail)
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
          when "wp"		  
              csvrec = "#{@mail_timestamp.to_s},mail_to=#{@mail_to.to_s} mail_from=#{@mail_from.to_s} subject=#{@subject.to_s} #{@body.to_s}"
          else
      end
  end
  #startegy for parsing mail body
  BK_DEL_MAIL_PARSER = lambda do | context |
      events = Hash.new
      isOpLog = false
      t_stamp_reg = "^[\\d]{4}-(0[1-9]|1[0-2])-[\\d]{2} (((0|1)[\\d]{1})|(2[0-4])):[0-5]{1}[\\d]{1}:[0-5]{1}[\\d]{1}\\.[\\d]{3}.+"
      p "parse body #{context[:body]}"
      begin
      body_to_lines = context[:body].split("\n")
          body_to_lines.each do | line |
	      test = Regexp.compile(t_stamp_reg,:INGORECASE)
              if test.match(line.strip) != nil then
                  p "match! #{line.strip}"
                  kv = line.split(" ") #timestamp,xx,xx,message	  
	          #key/val => process_time/various value
                  events[kv[0].strip] = "id1=#{kv[1]} id2=#{kv[2]} message=\"#{kv[3]}\" " + " mail_timestamp=\"#{context[:mail_timestamp]}\" mail_from=\"#{context[:mail_from]}\" mail_to=\"#{context[:mail_to]}\"  subject=\"#{context[:subject]}\"  mail_type=\"#{context[:mail_type]}\""
		  isOplog = true
              else
                  p "unmatch! #{line.strip}"
	      end
          end
      rescue
         p "excepion BK_DEL_MAILPERSER"
	 p $!
      end
      return events
  end
  LW_MAIL_PARSER = lambda do | context |
      events = Hash.new
      tmpBody = ""
      body_to_lines = context[:body].split("\n")
      body_to_lines.each do | line |
        if line =~ /:/ then
          key_val = line.split(":")
	  tmpBody = tmpBody + "#{key_val[0].strip}=#{key_cal[1].strip}  "
	end
      end
      #key/Value => mail_timestmap/dataa
      events[context[:mail_timestamp]] = " mail_from=\"#{context[:mail_from]}\" mail_to=\"#{context[:mail_to]}\"  subject=\"#{context[:subject]}\"  mail_type=\"#{context[:mail_type]}\" #{tmpBody[:body].strip}"
				
      return events
  end
  WP_MAIL_PARSER = lambda do | context |
      events = Hash.new
      #key/Value => mail_timestmap/data
      events[context[:mail_timestamp]] = "mail_from=\"#{context[:mail_from]}\" mail_to=\"#{context[:mail_to]}\"  subject=\"#{context[:subject]}\"  mail_type=#{context[:mail_type]} body=\"#{context[:body]}\""
      return events
  end
end
#-----------------------------------
#1.set parsing mode.
yml = YAML.load_file('mail_parser.yml')
case yml['config']['mode']
    when "eml"
	p "parse eml mails"
        mailDirector= ParsingDirector.new(EmlParser.new(yml['config']['eml_mail_path']))
    when "pop3"
	p "parse emails from pop server"
        mailDirector= ParsingDirector.new(POP3Parser.new(yml['credential']))
    when "imap"

    else
end
#parse e-mails and convert events formatted with hash list.
mailDirector.do

#output events.
mailDirector.write_to "oplog.mail"

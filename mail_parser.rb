require 'yaml'
require 'mail'
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
                @events.each do | event |
                  file.puts "#{event[0]},#{event[1]}"
                end
            end
        rescue
            p "excepion #{self.class.name}.#{__method__}"
            p $!
        end
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
end
class POP3Parser < ParserBuilder
   def initialize(credential)
       @credential = credential
       @events     = Array.new
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
                   parsed_events = mlpsr.parse_mail #return arrayed events
		   if parsed_events != nil then 
		       #parsed_events.each do |t_stamp,event | @events[t_stamp] = event end
                       parsed_events.each do | event |
                           @events.push event
                       end
                   end
	       end
	       p "events=> #{@events}"
	   end
           p "created #{@events.size.to_s} events."
       rescue
          p "excepion #{self.class.name}.#{__method__}"
	  p $!
       end
       return @events
   end
   MAIL_TO_HASH = lambda do | mail |
       if mail.multipart? == true then 
         tmp_body = mail.text_part.decoded 
       else
         tmp_body = mail.body.decoded
       end
       
       listed_mail = [[:mail_from,mail.from],
	             [:mail_to,mail.from],
		     [:subject,mail.subject],
		     [:date,mail.date.to_s],
		     [:body,tmp_body]
                    ]
       hashed_mail = Hash[*listed_mail.flatten(1)]
       #p "hased mail-> #{hashed_mail}"
       return hashed_mail
   end
end

class OplogMailParser
  LW_SVC="smllw"
  BK_DEL="bk_del"
  WP_SVC="wp_svc"
  def initialize(mail)
      @mail = mail #hased mail
  end
  def getMailTypeFromSubject(subject)
      regex_ptns = { LW_SVC =>"^Notification from SML",
                     BK_DEL =>"^\\[SML\\]\\[(Backup|Delete)\\] (Success|Fatal).+ ",
                     WP_SVC =>"^\\[SML Server Status! (Warning!|fiz).+"}
      begin
          #regex
	  p "test subject =>#{subject}"
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
              when BK_DEL
                  self.setParser(&BK_DEL_MAIL_PARSER)
              when LW_SVC
                  self.setParser(&LW_MAIL_PARSER)
              when WP_SVC
                  self.setParser(&WP_MAIL_PARSER)
              else
                   p "skipped this mail."
		   return nil
          end
          events = @bodyparser.call(@mail)
      rescue
         p "excepion #{self.class.name}.#{__method__}"
	 p $!
      end
    return events
  end
  #startegy for parsing mail body
  BK_DEL_MAIL_PARSER = lambda do | context |
      events = Array.new
      prev_time = ""
      t_stamp_reg = "^[\\d]{4}-(0[1-9]|1[0-2])-[\\d]{2} (((0|1)[\\d]{1})|(2[0-3])):[0-5]{1}[\\d]{1}:[0-5]{1}[\\d]{1}\\:[\\d]{3}"
      t_id        = "(\\d+)"
      t_message   = "(.+)"
      t_stamp_reg2 = "(^[\\d]{4}-(0[1-9]|1[0-2])-[\\d]{2} (((0|1)[\\d]{1})|(2[0-3])):[0-5]{1}[\\d]{1}:[0-5]{1}[\\d]{1}\\:[\\d]{3})"
      begin
      body_to_lines = context[:body].split("\n")
          body_to_lines.each do | line |
	      test = Regexp.compile(t_stamp_reg,:INGORECASE)
              if test.match(line.strip) != nil then
                  p "match! #{line.strip}"
		  data =/#{t_stamp_reg2}\s+#{t_id}\s+#{t_id}\s+#{t_id}\s+#{t_message}/.match(line.strip)
	          #key/val => process_time/various value
                  mail_from = context[:mail_from].join(" ")
		  mail_to   = context[:mail_from].join(" ")
		  tmpEvts= Array.new( [data[1] , "id1=#{data[7]} id2=#{data[8]} id3=#{data[9]} message=\"#{data[10]}\"  mail_timestamp=\"#{context[:date]}\" mail_from=\"#{mail_from.strip}\" mail_to=\"#{mail_to.strip}\"  subject=\"#{context[:subject]}\"  mail_type=\"#{context[:mail_type]}\""]  )
                   events.push tmpEvts
                   prev_time = data[1]
              else
                  p "unmatch! #{line.strip} (write to last events.#{prev_time})"
                  last_events = events.pop
		  events.push Array.new( [last_events[0],"#{last_events[1]} message=\"#{line.strip}\""] )
	      end
          end
      rescue
         p "excepion BK_DEL_MAILPERSER"
	 p $!
      end
      return events
  end
  LW_MAIL_PARSER = lambda do | context |
      events = Array.new
      tmpBody = ""
      body_to_lines = context[:body].split("\n")
      body_to_lines.each do | line |
        if line =~ /:/ then
          key_val = line.split(":")
	  tmpBody = tmpBody + "#{key_val[0].strip.gsub(/\s/,"_")}=\"#{key_val[1].strip}\"  "
	end
      end
      mail_from = context[:mail_from].join(" ")
      mail_to   = context[:mail_to].join(" ")
      events.push Array.new([context[:date] , " mail_from=\"#{mail_from}\" mail_to=\"#{mail_to}\"  subject=\"#{context[:subject]}\"  mail_type=\"#{context[:mail_type]}\" #{tmpBody.strip}" ])
				
      return events
  end
  WP_MAIL_PARSER = lambda do | context |
    events = Array.new
      tmpBody = ""
      mail_from = context[:mail_from].join(" ")
      mail_to   = context[:mail_to].join(" ")
      body_to_lines = context[:body].split("\n")
      body_to_lines.each do | line |
        if line =~ /:/ then
          key_val = line.split(":")
          tmpBody = tmpBody + "#{key_val[0].strip.gsub(/\s/,"_")}=\"#{key_val[1].strip}\"  "
        elsif line.strip.length > 0 then
          tmpBody = tmpBody + " message=\"#{line.strip}\" "
        end
      end
      #key/Value => mail_timestmap/data
      events.push Array.new([context[:date] , " mail_from=\"#{mail_from}\" mail_to=\"#{mail_to}\"  subject=\"#{context[:subject]}\" mail_type=\"#{context[:mail_type]}\" #{tmpBody.strip}" ])

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

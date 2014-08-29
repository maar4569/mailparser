require 'yaml'
require 'mail'
require_relative '../commonutils/exLogger.rb'
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
        if FileTest::Directory?( @eml_dir ) then
            begin
                Dir.glob( @eml_dir + "/**/*" ).each do | emlfile_path |
                    mlpsr = OplogMailParser.new( MAIL_TO_HASH.call Mail.read(emlfile_path) )
                    parsed_events = mlpsr.parse_mail #return arrayed events
                    if parsed_events != nil then
                       parsed_events.each do | event | @events.push event end
                    end
                end
            rescue
	        p $Log.fatal "exception #{self.class.name}.#{__method__}"
                p "excepion #{self.class.name}.#{__method__}"
	        p $Log.fatal $!
                p $!
            end
	end
        return @events
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
	       $Log.info "access to #{cred['hostname']} #{cred['port']}"
               retriever_method :pop3, :address    => cred['hostname'],
		                       :port       => cred['port'],
				       :user_name  => cred['username'],
	                               :password   => cred['password'],
				       :enable_ssl => cred['enable_ssl']
           end
	   #retrieve
	   mails = Mail.find(:what => :first, :count => 5, :order => :desc)
	   p "downloaded  #{mails.length} mail(s)"
	   $Log.info "downloaded #{mails.length} mail(s)."
	   if mails.length > 0 then
	       mails.each do | mail |
                   mlpsr = OplogMailParser.new( MAIL_TO_HASH.call mail )
                   parsed_events = mlpsr.parse_mail #return arrayed events
		   if parsed_events != nil then 
                       parsed_events.each do | event | @events.push event end
                   end
	       end
	       p "events=> #{@events}"
               $Log.debug "events=> #{@events}"
	   end
           p "created #{@events.size.to_s} events."
	   $Log.info "created #{@events.size.to_s} events."
       rescue
	  p $Log.fatal "exception #{self.class.name}.#{__method__}"
	  p $Log.fatal $!
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
       $Log.debug "hased mail-> #{hashed_mail}"
       return hashed_mail

   end
end
class MailAnlyzer
  def initialize(mail)
      @mail = mail
  end
  def parse_mail
      $Log.fatal "raise abstracted method(#{__method__}. please overwrite)"
  end
  def mail_to_hash

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
                     WP_SVC =>"^\\[SML Server Status! (Warning!|Normal!|Emergency!).+"}
      begin
          #regex
	  $Log.debug "test subject =>#{subject}"
	  regex_ptns.each do | k,v |
            test = Regexp.compile(v, Regexp::IGNORECASE)
	    if test.match(subject) != nil then
	      @mail[:mail_type] = k
	      break;
	    end
          end
          $Log.debug "mailtype is #{@mail[:mail_type]}"
      rescue
	  $Log.fatal "excepion #{self.class.name}.#{__method__}"
	  $Log.fatal  $!
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
	           $Log.warn "skipped. mail_type=\"skipped\" date=#{@mail[:date]} from=#{@mail[:mail_from]} subject=#{@mail[:subject]}"
                   p "skipped this mail."
		   return nil
          end
          events = @bodyparser.call(@mail)
      rescue
	 $Log.fatal "excepion #{self.class.name}.#{__method__}"
	 $Log.fatal $!
         p "excepion #{self.class.name}.#{__method__}"
	 p $!
      end
    return events
  end
  #startegy for parsing mail body
  BK_DEL_MAIL_PARSER = lambda do | context |
      events = Array.new
      last_time = ""
      last_evt = Hash.new
      t_stamp_reg = "^[\\d]{4}-(0[1-9]|1[0-2])-[\\d]{2} (((0|1)[\\d]{1})|(2[0-3])):[0-5]{1}[\\d]{1}:[0-5]{1}[\\d]{1}\\:[\\d]{3}"
      t_id        = "(\\d+)"
      t_message   = "(.+)"
      begin
          body_to_lines = context[:body].split("\n")
          body_to_lines.each do | line |
	      test = Regexp.compile(t_stamp_reg,:INGORECASE)
              if test.match(line.strip) != nil then
                  p "match! #{line.strip}"
		  $Log.debug "match! #{line.strip}"
		  data =/(#{t_stamp_reg})\s+#{t_id}\s+#{t_id}\s+#{t_id}\s+#{t_message}/.match(line.strip)
	          #key/val => process_time/various value
                  mail_from = context[:mail_from].join(" ")
		  mail_to   = context[:mail_from].join(" ")
		  
		  #make hash and convert hash to key/value strings without event date.
		  tmp_h_evt  = { "id1"=>data[7] ,"id2"=>data[8] , "id3"=>data[9] ,"message"=>data[10] ,"mail_timestamp"=>context[:date], "mail_from"=>mail_from.strip, "mail_to"=>mail_to.strip , "subject"=>context[:subject], "mail_type"=>context[:mail_type] }
		  evt_str = ""
		  tmp_h_evt.each do | k,v | evt_str = "#{evt_str} #{k}=\"#{v}\"" end
		  tmpEvts = Array.new( [ data[1] , evt_str] )
                  #add event
                  events.push tmpEvts
                  last_time = data[1]
	          last_evt = Marshal.load( Marshal.dump(tmp_h_evt) )
	      else
		  $Log.debug "unmatch! #{line.strip} (write to last events.#{last_time})"
                  p "unmatch! #{line.strip} (write to last events.#{last_time})"
		  #add unmatched strings to message.
		  events.pop
		  last_evt["message"] = "#{last_evt["message"]} \\n #{line.strip}"
		  #update event.
		  updEvt=""
		  last_evt.each do | k,v | updEvt = "#{updEvt} #{k}=\"#{v}\"" end
		  $Log.debug "updated events=>#{updEvt.strip}"
		  events.push Array.new( [last_time , updEvt.strip ])
	      end
          end
      rescue
	 $Log.fatal "exception BK_DEL_MAILPERSER"
	 $Log.fatal $!
         p "excepion BK_DEL_MAILPERSER"
	 p $!
      end
      $Log.debug "added event=>#{events.last}"
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
      $Log.debug "added events=>#{events.last}"
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
      $Log.debug "added events=>#{events.last}"
      return events
  end
end
#-----------------------------------
#1.set parsing mode.
include LoggerConf
yml = YAML.load_file('mail_parser.yml')
$Log       = Logger.new( yml['config']['logfile'], 'daily' )
$Log.level = LoggerConf.level (yml['config']['loglevel'])

case yml['config']['mode']
    when "eml"
	$Log.info "parse eml mails."
	p "parse eml mails"
        mailDirector= ParsingDirector.new(EmlParser.new(yml['config']['eml_mail_path']))
    when "pop3"
	$Log.info "parse emails from pop server"
	p "parse emails from pop server"
        mailDirector= ParsingDirector.new(POP3Parser.new(yml['credential']))
    when "imap"

    else
end
#parse e-mails and convert events formatted with hash list.
mailDirector.do

#output events.
mailDirector.write_to "oplog.mail"


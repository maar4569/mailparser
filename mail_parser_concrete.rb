require 'yaml'
require 'mail'
require_relative '../commonutils/exLogger.rb'
require_relative './mail_parser_core.rb'
#concreate builder
class EmlReader < ReaderBuilder
    def initialize(eml_dir , analyzer)
        @eml_dir = eml_dir
	@events  = Hash.new
        @mlpsr   = analyzer
    end
    def retrieve_mail
        p "#{self.class.name}.#{__method__} from #{@eml_dir}"
        if FileTest::Directory?( @eml_dir ) then
            begin
                Dir.glob( @eml_dir + "/**/*" ).each do | emlfile_path |
                    @mlpsr.load( Mail.read(emlfile_path) )
                    parsed_events = @mlpsr.parse_mail #return arrayed events
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
class POP3Reader < ReaderBuilder
   def initialize(credential , analyzer)
       @credential = credential
       @events     = Array.new
       @mlpsr      = analyzer
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
                   @mlpsr.load( mail )
                   parsed_events = @mlpsr.parse_mail #return arryed events
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
end
class OplogMailAnalyzer < MailAnalyzer
  LW_SVC="smllw"
  BK_DEL="bk_del"
  WP_SVC="wp_svc"
  def initialize
      super
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
                  events = MailAnalysys.parse_bk_del(@mail)
              when LW_SVC
                  events = MailAnalysys.parse_lw(@mail)
              when WP_SVC
                  events = MailAnalysys.parse_wp(@mail)
              else
	           $Log.warn "skipped. mail_type=\"skipped\" date=#{@mail[:date]} from=#{@mail[:mail_from]} subject=#{@mail[:subject]}"
                   p "skipped this mail."
		   return nil
          end
      rescue
	 $Log.fatal "excepion #{self.class.name}.#{__method__}"
	 $Log.fatal $!
         p "excepion #{self.class.name}.#{__method__}"
	 p $!
      end
    return events
  end
end

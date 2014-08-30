require_relative '../logger/exlogger.rb'
require_relative './analyzer.rb'
require_relative './analyzer_module.rb'

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

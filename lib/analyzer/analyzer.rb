require_relative '../logger/exlogger.rb'
require_relative './analyzer_module.rb'
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

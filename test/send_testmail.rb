require 'mail'

class MailAgent
    def initialize(credential)
        raise "call abstract method!"
    end
    def send_to
        raise "call abstract method!"
    end
end
class SmtpSender < MailAgent
    def initialize(credential)
      @credential = credential
    end
    def send(mail)
	cred = @credential
	p "credential=>#{cred}"
        begin
	    Mail.defaults do
                delivery_method :smtp,
			        :address         => cred['hostname'],
			        :port            => cred['port'] ,
		                :domain          => cred['domain'],
				:authentication  => cred['auth_type'],
		                :user_name       => cred['username'],
				:password        => cred['password'],
				:ssl             => cred['ssl']
	    end
	    p "smtp server config OK"
	    p "mail contents=>#{mail}"
	    Mail.deliver do
              from    mail[:mail_from]
	      to      mail[:mail_to]
	      subject mail[:subject]
	      body    File.read(mail[:body])
	    end
	rescue
	    p "exception #{self.class.name}.#{__method__}"
	    p $!
	end
    end
end

#####main#####################
yml = YAML.load_file('mail_deliver.yml')

mail_sender = SmtpSender.new(yml['credential'])

mail = {:mail_from => "xxxx@gmail.com",
        :mail_to   => "yyyy@gmail.com",
        :subject   => "test"}


file1 = "mail_body.txt"
mail[:body] = file1
mail[:subject] = "hello"
mail_sender.send mail




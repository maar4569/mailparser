require_relative '../logger/exlogger.rb'
module MailAnalysys
    #input hashed mail
    def parse_lw( mail )
       events = Array.new
       tmpBody = ""
       body_to_lines = mail[:body].split("\n")
       body_to_lines.each do | line |
           if line =~ /:/ then
               key_val = line.split(":")
               tmpBody = tmpBody + "#{key_val[0].strip.gsub(/\s/,"_")}=\"#{key_val[1].strip}\"  "
           end
      end
      mail_from = mail[:mail_from].join(" ")
      mail_to   = mail[:mail_to].join(" ")
      events.push Array.new([mail[:date] , " mail_from=\"#{mail_from}\" mail_to=\"#{mail_to}\"  subject=\"#{mail[:subject]}\"  mail_type=\"#{mail[:mail_type]}\" #{tmpBody.strip}" ])
      $Log.debug "added events=>#{events.last}"
      return events
    end
    def parse_bk_del( mail )
      events = Array.new
      last_time = ""
      last_evt = Hash.new
      t_stamp_reg = "^[\\d]{4}-(0[1-9]|1[0-2])-[\\d]{2} (((0|1)[\\d]{1})|(2[0-3])):[0-5]{1}[\\d]{1}:[0-5]{1}[\\d]{1}\\:[\\d]{3}"
      t_id        = "(\\d+)"
      t_message   = "(.+)"
      begin
          body_to_lines = mail[:body].split("\n")
          body_to_lines.each do | line |
              test = Regexp.compile(t_stamp_reg,:INGORECASE)
              if test.match(line.strip) != nil then
                  p "match! #{line.strip}"
                  $Log.debug "match! #{line.strip}"
                  data =/(#{t_stamp_reg})\s+#{t_id}\s+#{t_id}\s+#{t_id}\s+#{t_message}/.match(line.strip)
                  #key/val => process_time/various value
                  mail_from = mail[:mail_from].join(" ")
                  mail_to   = mail[:mail_from].join(" ")

                  #make hash and convert hash to key/value strings without event date.
                  tmp_h_evt  = { "id1"=>data[7] ,"id2"=>data[8] , "id3"=>data[9] ,"message"=>data[10] ,"mail_timestamp"=>mail[:date], "mail_from"=>mail_from.strip, "mail_to"=>mail_to.strip , "subject"=>mail[:subject], "mail_type"=>mail[:mail_type] }
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
    def parse_wp( mail )
        events = Array.new
        tmpBody = ""
        mail_from = mail[:mail_from].join(" ")
        mail_to   = mail[:mail_to].join(" ")
        body_to_lines = mail[:body].split("\n")
        body_to_lines.each do | line |
            if line =~ /:/ then
                key_val = line.split(":")
                tmpBody = tmpBody + "#{key_val[0].strip.gsub(/\s/,"_")}=\"#{key_val[1].strip}\"  "
            elsif line.strip.length > 0 then
                tmpBody = tmpBody + " message=\"#{line.strip}\" "
            end
        end
        #key/Value => mail_timestmap/data
        events.push Array.new([mail[:date] , " mail_from=\"#{mail_from}\" mail_to=\"#{mail_to}\"  subject=\"#{mail[:subject]}\" mail_type=\"#{mail[:mail_type]}\" #{tmpBody.strip}" ])
        $Log.debug "added events=>#{events.last}"
        return events
    end
    def mail_to_hash( mail )
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
    module_function :parse_wp, :parse_bk_del, :parse_lw, :mail_to_hash
end

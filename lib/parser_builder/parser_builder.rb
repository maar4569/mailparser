require 'mail'
require_relative '../logger/exlogger.rb'
#builder interface
class ReaderBuilder
    def initialize
        raise "called abstract method(initialize)"   
    end
    def retrieve_mail
        raise "called abstract method(retrieve_mail)"
    end
end

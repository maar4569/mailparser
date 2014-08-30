require 'logger'
EXCEPTION_MESSAGE='exception happend.'
LVL_FATAL='FATAL'
LVL_ERROR='ERROR'
LVL_WARN='WARN'
LVL_INFO='INFO'
LVL_DEBUG='DEBUG'

module LoggerConf
    def level(level)
        if level =~ /FATAL|ERROR|WARN|INFO|DEBUG/ then
            case level
                when LVL_FATAL
                    return Logger::FATAL
                when LVL_ERROR
                    return Logger::ERROR
                when LVL_WARN
                    return Logger::WARN
                when LVL_INFO
                    return Logger::INFO
                when LVL_DEBUG
                    return Logger::DEBUG
                else
            end
        end
        return nil
    end
end

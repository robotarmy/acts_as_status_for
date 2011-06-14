module ActsAsStatusFor
  def self.included(base)
    base.instance_eval do
      include InstanceMethods
    end
    base.extend(ClassMethods)
  end
  module ClassMethods
    def acts_as_status_for(*status_marks)
      @on_at_events  = status_marks
      @off_at_events = on_at_events.collect do | event |
        "not_#{event.to_s}".to_sym
      end
      install_scopes
      install_methods
    end
    def install_scopes
      p self
      on_at_events.each do |state|
        scope "#{state}".to_sym, where(self.arel_table["#{state}_at".to_sym].not_eq(nil))
        scope "not_#{state}".to_sym, where(self.arel_table["#{state}_at".to_sym].eq(nil))
      end
    end
    def install_methods
      on_at_events.each do |state|
        define_method "#{state}?" do
          !read_attribute("#{state}_at".to_sym).nil?
        end

        define_method "not_#{state}!" do
          if self.__send__("#{state}?")
            self.send("#{state}_at=".to_sym,nil)
            self.save!
          end
        end

        define_method "#{state}!" do
          unless self.__send__("#{state}?")
            self.send("#{state}_at=".to_sym,Time.now)
            self.save!
          end
        end
      end
    end
    def off_at_events
      @off_at_events
    end
    def all_at_events
      @all_at_events ||= ( off_at_events | on_at_events )
    end
    def on_at_events
      @on_at_events
    end
  end
  module InstanceMethods

    def status=(event)
      case event
      when ''
        self.off_at_events.each do | event |
          self.send("#{event}!")
        end
      else
        if self.all_at_events.include?(event.to_sym)
          self.send("#{event}!")
        end
      end
    end

    def status
      status = []
      self.on_at_events.each do |event| 
        status << event.to_s if self.send("#{event}?")
      end
      status.join(' ')
    end
  end
end


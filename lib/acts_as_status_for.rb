module ActsAsStatusFor
  def self.included(base)
    base.instance_eval do
      include InstanceMethods
    end
    base.extend(ClassMethods)
  end
  module ClassMethods

    def acts_as_status_for(*status_marks,&after_migrations)
      @all_status_marks_exist = true
      @on_at_events  = status_marks
      @off_at_events = on_at_events.collect do | event |
        "not_#{event.to_s}".to_sym
      end
      install_scopes
      install_methods
      after_migrations.call(self) if @all_status_marks_exist && block_given?
    end
    def log_error(state)
      STDERR.puts "Arel could not find #{state}_at in the database - skipping installation of acts_as_status"
    end
    def install_scopes
      on_at_events.each do |state|
        if self.arel_table["#{state}_at".to_sym] then
          scope "#{state}".to_sym, where(self.arel_table["#{state}_at".to_sym].not_eq(nil))
          scope "not_#{state}".to_sym, where(self.arel_table["#{state}_at".to_sym].eq(nil))
        else
          log_error(state)
          @all_status_marks_exist = @all_status_marks_exist && false
        end
      end
    end

    def install_methods
      on_at_events.each do |state|
        if self.arel_table["#{state}_at".to_sym] then
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
        else
          log_error(state)
          @all_status_marks_exist = @all_status_marks_exist && false
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
    def current_status
      status.split(' ').first or ''
    end
    def status=(event_string)
      case event_string
      when ''
        self.class.off_at_events.each do | event |
          self.send("#{event}!") if self.respond_to?("#{event}!")
        end
      else
        event_string.split(' ').each do | event |
          if self.class.all_at_events.include?(event.to_sym)
            self.send("#{event}!") if self.respond_to?("#{event}!")
          end
        end
      end
    end

    def status
      status_time = {}
      self.class.on_at_events.each do | event |
        time = self.send("#{event}_at")
        status_time[event] = time unless time.nil?
      end
      status_time.sort { |a,b| b.last <=> a.last }.collect(&:first).join(' ')
    end
  end
end

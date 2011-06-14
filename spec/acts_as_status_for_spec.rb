require 'spec_helper'
class Job
  include ActsAsStatusFor
  acts_as_status_for :on_hold, :archived, :featured
end

describe ActsAsStatusFor do
  subject {
    Job.new
  }
  context "#status" do
    it "defaults to ''" do
      subject.status.should == ''
    end

    it "setting it to blank clears all states" do
      subject.on_hold!
      subject.archived!
      subject.featured!
      subject.status = ''
      subject.status.should == ''
    end
    {
      # class finder method 
      #          => [ list of event states that belong to finder]
      #
        :featured  => [:featured],
        :on_hold   => [:on_hold],
        :archived  => [:archived]
    }.each do |scope,states|
      states.each do |state|
        it "can be used to set events" do
          subject.status = state.to_s
          subject.send(%%#{state}?%).should be_true
          subject.status.should include(state.to_s)
        end

        it "can be reversed" do
          subject.status = state.to_s
          subject.send("#{state}?").should be_true
          subject.status = "not_" + state.to_s
          subject.send("#{state}?").should be_false
        end

        it "#{state} sets state string" do
          subject.send("#{state}!")
          subject.send("#{state}?").should be_true
          subject.status.should include(state.to_s)
        end

        it "#{state} is in the scope #{scope}" do
          subject.send("#{state}!")
          subject.send("#{state}?").should be_true
          subject.class.send(scope).should include(subject)
        end
      end
    end
  end
end



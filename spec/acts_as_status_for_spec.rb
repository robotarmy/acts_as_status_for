require 'spec_helper'

ActiveRecord::Migration.create_table :things do |t|
  t.string   :name
  t.datetime :on_hold_at
  t.datetime :archived_at
  t.datetime :featured_at
end

class Thing < ActiveRecord::Base
  include ActsAsStatusFor
  validates_presence_of :name # ensure that this works with required fields (no ! on save)
end

describe ActsAsStatusFor do
  subject {
    Thing.new(:name => 'required')
  }
  context "for non-existing fields" do
    before do
      @ran = false
      Thing.instance_eval do
        acts_as_status_for :happing do
          @ran = true
        end
      end
    end
    it "does not execute block" do
      @ran.should be_false
    end
  end
  context "install dependent helpers" do
    before do
      Thing.instance_eval do
        acts_as_status_for :on_hold, :archived, :featured do
          scope :depends_on, not_on_hold.not_archived
        end
      end
    end
    it "#depends_on" do
      subject.class.respond_to?(:depends_on).should be_true
    end
  end

  context "#current_status" do
    it 'has a setter' do
      subject.current_status = 'on_hold'
      subject.on_hold?.should be_true
    end

    it 'reveals the last status set' do
      subject.on_hold!
      subject.current_status.should == 'on_hold'
    end

    it 'can go back and forth between two events' do
      subject.on_hold!
      subject.current_status.should == 'on_hold'
      subject.archived!
      subject.current_status.should == 'archived'
      subject.on_hold!
      subject.current_status.should == 'on_hold'
      subject.on_hold_at > subject.archived_at
    end

    it 'can be wound and unwound' do
      subject.on_hold!
      subject.current_status.should == 'on_hold'
      subject.archived!
      subject.current_status.should == 'archived'
      subject.featured!
      subject.current_status.should == 'featured'
      subject.not_featured!
      subject.current_status.should == 'archived'
      subject.not_archived!
      subject.current_status.should == 'on_hold'
      subject.not_on_hold!
      subject.current_status.should == ''
    end
  end

  context "#status" do
    before do
      Thing.instance_eval do
        acts_as_status_for :on_hold, :archived, :featured
      end
    end

    it "defaults to ''" do
      subject.status.should == ''
    end

    it "is sorted by event time" do
      subject.on_hold!
      subject.status.should == 'on_hold'
      subject.archived!
      subject.status.should == 'archived on_hold'
      subject.featured!
      subject.status.should == 'featured archived on_hold'
      subject.not_on_hold!
      subject.on_hold!
      subject.status.should == 'on_hold featured archived'
    end

    it "setting it to blank clears all states" do
      subject.on_hold!
      subject.archived!
      subject.featured!
      subject.status = ''
      subject.status.should == ''
    end

    describe "audit trail is independent of scope" do
      it "should recognize only the most recent" do
        subject.featured_at = 3.days.ago
        subject.on_hold_at = 1.days.ago
        subject.archived_at = Time.now
        subject.save
        subject.class.archived.should     include(subject)
        subject.class.not_on_hold.should  include(subject)
        subject.class.on_hold.should_not  include(subject)
        subject.class.not_featured.should include(subject)
        subject.class.featured.should_not include(subject)
      end
    end

    (ClassFinderMethods = {
      # class finder method 
      #          => [ list of event states that belong to finder]
      #
      :featured  => [:featured],
      :on_hold   => [:on_hold],
      :archived  => [:archived]
    }).each do |scope,states|
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



require 'spec_helper'

ActiveRecord::Migration.create_table :things do |t|
  t.datetime :on_hold_at
  t.datetime :archived_at
  t.datetime :featured_at
end

class Thing < ActiveRecord::Base
  include ActsAsStatusFor
end

describe ActsAsStatusFor do
  subject {
    Thing.new
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

  context "#status" do
    before do
      Thing.instance_eval do
        acts_as_status_for :on_hold, :archived, :featured
      end
    end
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



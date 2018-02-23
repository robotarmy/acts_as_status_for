require 'spec_helper'

ActiveRecord::Migration.create_table :things do |t|
  t.string   :name
  t.string   :type # allow single table inheritance
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
      expect(@ran).to be_falsey
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
      expect(subject.class.respond_to?(:depends_on)).to be_truthy
    end
  end

  context "#current_status" do
    it 'has a setter' do
      subject.current_status = 'on_hold'
      expect(subject.on_hold?).to be_truthy
    end

    it 'reveals the last status set' do
      subject.on_hold!
      expect(subject.current_status).to eq('on_hold')
    end

    it 'can go back and forth between two events' do
      subject.on_hold!
      expect(subject.current_status).to eq('on_hold')
      subject.archived!
      expect(subject.current_status).to eq('archived')
      subject.on_hold!
      expect(subject.current_status).to eq('on_hold')
      subject.on_hold_at > subject.archived_at
    end

    it 'can be wound and unwound' do
      subject.on_hold!
      expect(subject.current_status).to eq('on_hold')
      subject.archived!
      expect(subject.current_status).to eq('archived')
      subject.featured!
      expect(subject.current_status).to eq('featured')
      subject.not_featured!
      expect(subject.current_status).to eq('archived')
      subject.not_archived!
      expect(subject.current_status).to eq('on_hold')
      subject.not_on_hold!
      expect(subject.current_status).to eq('')
    end
  end
  context "#status_including_" do
    it "#respond_to? :status_including_archived" do
      subject.respond_to? :status_including_archived
    end
    it "archived" do
      expect(subject.class.status_including_archived).not_to include(subject)
      subject.archived!
      expect(subject.class.status_including_archived).to include(subject)
    end
    it "archived_and_featured" do
      expect(subject.class.status_including_archived_and_featured).not_to include(subject)
      subject.archived!
      expect(subject.class.status_including_archived_and_featured).not_to include(subject)
      subject.featured!
      expect(subject.class.status_including_archived_and_featured).to include(subject)
    end
    it "archived_and_featured_and_on_hold" do
      expect(subject.class.status_including_archived_and_featured_and_on_hold).not_to include(subject)
      subject.archived!
      expect(subject.class.status_including_archived_and_featured_and_on_hold).not_to include(subject)
      subject.featured!
      expect(subject.class.status_including_archived_and_featured_and_on_hold).not_to include(subject)
      subject.on_hold!
      expect(subject.class.status_including_archived_and_featured_and_on_hold).to include(subject)
    end
  end
  context "#status" do
    context "with multi object inheritance" do
      before do
        Thing.instance_eval do
          acts_as_status_for :on_hold, :archived, :featured
        end
        class ThingA < Thing

        end
        class ThingB < ThingA

        end
      end
      context "it searches inheritance tree for on_at_methods" do
        subject {
          ThingB.new(:name => 'required')
        }
        it "defaults to ''" do
          expect(subject.status).to eq('')
        end
        it "uses superclasse status" do
          subject.on_hold!
          expect(subject.status).to eq('on_hold')
        end
      end
    end

    context "with single object" do
      before do
        Thing.instance_eval do
          acts_as_status_for :on_hold, :archived, :featured
        end
      end

      it "defaults to ''" do
        expect(subject.status).to eq('')
      end

      it "allows negation of status using 'not_' prefix" do
        subject.on_hold!
        subject.archived!
        expect(subject.status).to eq('archived on_hold')
        subject.status = "not_archived"
        expect(subject.status).to eq('on_hold')
      end

      it "is sorted by event time" do
        subject.on_hold!
        expect(subject.status).to eq('on_hold')
        subject.archived!
        expect(subject.status).to eq('archived on_hold')
        subject.featured!
        expect(subject.status).to eq('featured archived on_hold')
        subject.not_on_hold!
        subject.on_hold!
        expect(subject.status).to eq('on_hold featured archived')
      end

      it "setting it to blank clears all states when clear_status is true" do
        subject.on_hold!
        subject.archived!
        subject.featured!
        subject.status=('',clear_status: true)
        expect(subject.status).to eq('')
      end


      describe "audit trail is independent of scope" do
        it "should recognize only the most recent" do
          subject.featured_at = 3.days.ago
          subject.on_hold_at = 1.days.ago
          subject.archived_at = Time.now
          subject.save
          expect(subject.class.archived).to     include(subject)
          expect(subject.class.not_on_hold).to  include(subject)
          expect(subject.class.on_hold).not_to  include(subject)
          expect(subject.class.not_featured).to include(subject)
          expect(subject.class.featured).not_to include(subject)
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
            expect(subject.send(%%#{state}?%)).to be_truthy
            expect(subject.status).to include(state.to_s)
          end

          it "can be reversed" do
            subject.status = state.to_s
            expect(subject.send("#{state}?")).to be_truthy
            subject.status = "not_" + state.to_s
            expect(subject.send("#{state}?")).to be_falsey
          end

          it "#{state} sets state string" do
            subject.send("#{state}!")
            expect(subject.send("#{state}?")).to be_truthy
            expect(subject.status).to include(state.to_s)
          end

          it "#{state} is in the scope #{scope}" do
            subject.send("#{state}!")
            expect(subject.send("#{state}?")).to be_truthy
            expect(subject.class.send(scope)).to include(subject)
          end
        end
      end
    end
  end
end



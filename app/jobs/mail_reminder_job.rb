require 'set'
require 'colorize'

class MailReminderJob < ActiveJob::Base
  queue_as :default

  def perform(env)
    mail_data = Hash.new{|h, k| h[k] = Set.new}
    reminders = MailReminder.select do |rem|
      if rem.project
        next(false) unless rem.project.enabled_module_names.include?('issue_reminder')
        next(false) unless rem.query.present?
        print "Project \"#{ rem.project.name }\" with query \"#{ rem.query.name }\" "
        if env == "test"
          puts "\t is forced processing under [test] mode.".yellow
          next(true)
        end
        if rem.execute?
          puts "\t is processing.".light_blue
          next(true)
        else
          puts "\t is ignored. It's executed recently and too early for next execution.".red
          next(false)
        end
      end
    end
    
    reminders.sort{|l,r| l.project_id <=> r.project_id}.each do |rem|
      rem.roles.each do |role|
        role.members.select {|m| m.project_id == rem.project_id}.
          reject {|m| m.user.nil? || m.user.locked?}.
          each do |member|
            mail_data[member.user] << [rem.project, rem.query]
            rem.executed_at = Time.now if env != "test"
            rem.save
          end
      end
    end

    MailReminderMailer.with_synched_deliveries do
      mail_data.each do |user, queries_data|
        MailReminderMailer.issues_reminder(user, queries_data).deliver if user.active?
        puts user.mail
      end
    end
  end
end

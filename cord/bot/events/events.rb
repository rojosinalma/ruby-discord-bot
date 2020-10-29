module Cord
  module Events
    extend Discordrb::EventContainer

    ready do |event|
      event.bot.game = ENV['DISCORD_BOT_GAME']
    end

    channel_update do |event|
      # Channel filter
      if event.channel.name == "helm"
        last_entry = event.server.audit_logs.entries.select{|entry| (entry.action_type == :update) && entry.target_type == :channel}.first

        # Audit log filter
        return unless event.channel.name == last_entry.target.name

        # Fetch info from Discord
        begin
          raise("First letter is not R") if event.channel.topic.chars[0] == "R"
          event_topic = event.channel.topic
          audit_user  = last_entry.user
          audit_date  = last_entry.creation_time

          # Fetch names from GH repo.
          res          = Github.repos.contents.get 'R1sk-Org', 'R1SK', 'names.json'
          content      = JSON.parse(Base64.decode64(res.body.content))
          content_hash = content.kind_of?(Hash) ? content : Hash.new

          raise("Empty names.json") if content_hash.fetch('names', []).last.nil?

          last_topic   = content_hash['names'].last['name'] unless content_hash.fetch('names', []).last.nil?
        rescue => e
          puts "Catched error: #{e.message}"
          return # Fail semi-silently
        end

        # Save to Github
        unless (event_topic == last_topic)
          updated_content = content_hash['names'].push({ "name" => event_topic, "author" => audit_user.username, "date" => audit_date.strftime("%m/%d/%Y") })
          content         = { names: updated_content }

          Github.repos.contents.update('R1SK-Org', 'R1SK', 'names.json', path: 'names.json', content: content.to_json, message: "New topic from Discord", sha: res.body.sha )
        end
      end
    end
  end
end

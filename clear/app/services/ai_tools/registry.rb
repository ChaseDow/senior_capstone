module AiTools
  class Registry
    TOOL_CLASSES = [
      AiTools::DraftEvent,
      AiTools::DraftCourse,
      AiTools::DraftCourseItem
    ].freeze

    def self.declarations
      TOOL_CLASSES.map(&:definition)
    end

    def self.execute(name:, user:, args:)
      tool_class = TOOL_CLASSES.find { |tool| tool.definition[:name] == name }
      return { error: "Unknown function: #{name}" } unless tool_class

      tool_class.call(user: user, args: args)
    end
  end
end

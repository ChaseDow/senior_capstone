# frozen_string_literal: true

require "stringio"
require "pdf/reader"
require "docx"

module Syllabuses
  class TextExtractor
    def self.call(syllabus)
      raise "No file attached" unless syllabus.file.attached?

      if syllabus.is_pdf?
        extract_pdf(syllabus)
      elsif docx_content_type?(syllabus)
        extract_docx_or_doc(syllabus)
      else
        raise "Unsupported file type: #{syllabus.file.content_type}"
      end
    end

    def self.extract_pdf(syllabus)
      data = syllabus.file.download
      reader = PDF::Reader.new(StringIO.new(data))
      reader.pages.map(&:text).join("\n")
    end

    def self.extract_docx_or_doc(syllabus)
      ext = syllabus.file_extension

      case ext
      when ".docx"
        extract_docx(syllabus)
      when ".doc"
        # Option 1 (simple): fail with helpful message
        raise "'.doc' files aren’t supported yet. Please upload a PDF or DOCX."

        # Option 2 (if you want .doc support later):
        # extract_doc_with_antiword(syllabus)
      else
        raise "Unknown Word extension: #{ext}"
      end
    end

    def self.extract_docx(syllabus)
      Tempfile.create([ "syllabus", ".docx" ]) do |tmp|
        tmp.binmode
        tmp.write(syllabus.file.download)
        tmp.flush

        doc = Docx::Document.open(tmp.path)
        doc.paragraphs.map(&:text).join("\n")
      end
    end

    def self.docx_content_type?(syllabus)
      syllabus.file.content_type.in?([
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword"
      ])
    end

    # If later you want .doc support:
    # def self.extract_doc_with_antiword(syllabus)
    #   require "open3"
    #   Tempfile.create(["syllabus", ".doc"]) do |tmp|
    #     tmp.binmode
    #     tmp.write(syllabus.file.download)
    #     tmp.flush
    #
    #     stdout, stderr, status = Open3.capture3("antiword", tmp.path)
    #     raise "antiword failed: #{stderr}" unless status.success?
    #     stdout
    #   end
    # end
  end
end

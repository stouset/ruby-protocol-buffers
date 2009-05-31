require 'protobuf/compiler/descriptor.pb'
require 'stringio'

class FileDescriptorToRuby < Struct.new(:descriptor)

  def initialize(descriptor)
    super
    @package = capfirst(descriptor.package)
    @ns = []
  end

  def write(io)
    @io = io

    @io.write <<HEADER
#!/usr/bin/env ruby
# Generated by the protocol buffer compiler. DO NOT EDIT!

require 'protobuf/message/message'

HEADER

    in_namespace("module", @package) do
      declare(descriptor.message_type, descriptor.enum_type)

      descriptor.message_type.each do |message|
        dump_message(message)
      end

      descriptor.enum_type.each do |enum|
        dump_enum(enum)
      end
    end

  end

  protected

  def declare(messages, enums)
    return if messages.empty? && enums.empty?

    line %{# forward declarations}
    messages.each do |message|
      line %{class #{name([@package, message.name])} < ::Protobuf::Message; end}
    end
    enums.each do |enum|
      line %{class #{name([@package, enum.name])} < ::Protobuf::Enum; end}
    end
    line
  end

  def line(str = nil)
    if str
      @ns.size.times { @io.write("  ") }
      @io.write(str)
    end
    @io.write("\n")
  end

  def in_namespace(type, name, rest = "")
    if !name
      yield
    else
      line "#{type} #{capfirst(name)} #{rest}"
      @ns.push name
      yield
      @ns.pop
      line "end"
    end
  end

  def name(parts)
    ns = @ns.dup
    (parts.shift; ns.shift) while !parts.empty? && parts.first == ns.first
    parts.map { |p| capfirst(p) }.join("::")
  end

  LABEL_MAPPING = {
    FieldDescriptorProto::Label::LABEL_OPTIONAL => "optional",
    FieldDescriptorProto::Label::LABEL_REQUIRED => "required",
    FieldDescriptorProto::Label::LABEL_REPEATED => "repeated",
  }

  TYPE_MAPPING = {
    FieldDescriptorProto::Type::TYPE_DOUBLE => ":double",
    FieldDescriptorProto::Type::TYPE_FLOAT => ":float",
    FieldDescriptorProto::Type::TYPE_INT64 => ":int64",
    FieldDescriptorProto::Type::TYPE_UINT64 => ":uint64",
    FieldDescriptorProto::Type::TYPE_INT32 => ":int32",
    FieldDescriptorProto::Type::TYPE_FIXED64 => ":fixed64",
    FieldDescriptorProto::Type::TYPE_FIXED32 => ":fixed32",
    FieldDescriptorProto::Type::TYPE_BOOL => ":bool",
    FieldDescriptorProto::Type::TYPE_STRING => ":string",
    FieldDescriptorProto::Type::TYPE_BYTES => ":bytes",
    FieldDescriptorProto::Type::TYPE_UINT32 => ":uint32",
    FieldDescriptorProto::Type::TYPE_SFIXED32 => ":sfixed32",
    FieldDescriptorProto::Type::TYPE_SFIXED64 => ":sfixed64",
    FieldDescriptorProto::Type::TYPE_SINT32 => ":sint32",
    FieldDescriptorProto::Type::TYPE_SINT64 => ":sint64",
  }

  def dump_message(message)
    in_namespace("class", message.name, "< ::Protobuf::Message") do
      declare(message.nested_type, message.enum_type)

      line %{# nested messages} unless message.nested_type.empty?
      message.nested_type.each { |inner| dump_message(inner) }

      line %{# nested enums} unless message.enum_type.empty?
      message.enum_type.each { |inner| dump_enum(inner) }

      message.field.each do |field|
        typename = TYPE_MAPPING[field.type] || field.type_name.split(".").map { |t| capfirst(t) }.join("::")
        fieldline = %{#{LABEL_MAPPING[field.label]} #{typename}, :#{field.name}, #{field.number}}
        if field.default_value && field.default_value != ""
          # TODO: this probably doesn't work for all default values, expand
          fieldline << %{, :default => #{field.default_value}}
        end
        line fieldline
      end
    end
    line
  end

  def dump_enum(enum)
    in_namespace("class", enum.name, "< ::Protobuf::Enum") do
      enum.value.each do |value|
        line %{#{capfirst(value.name)} = #{value.number}}
      end
    end
    line
  end

  def capfirst(s)
    "#{s[0,1].capitalize}#{s[1..-1]}" if s
  end

  def output(line)
    @curfile.write("  " * @indent)
    @curfile.write(line)
    @curfile.write("\n")
  end

  def name_with_package(nm)
    if @package
      "#{capfirst(@package)}::#{nm}"
    else
      nm
    end
  end

end

#!/usr/bin/env ruby
require 'yaml'
require 'delegate'

URL = "https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/"

class NodeWrapper < SimpleDelegator

  def initialize(delegatee, parent = nil)
    super delegatee
    @parent = parent
  end

  def href
    return self["a_attr"]["href"]
  end

  def absolute_url
    return "#{URL}#{href}"
  end

  def name
    return self["text"]
  end
end

class NamespaceWrapper < NodeWrapper

  def initialize(delegatee)
    super delegatee
  end

  def get_cls(name)
    self["children"].each do |cls|
      if cls["text"] =~ /^#{name} Class$/i
        return ClassWrapper.new(cls, self)
      end
    end
    return nil
  end

end

class ClassWrapper < NodeWrapper

  def initialize(delegatee, parent = nil)
    super delegatee, parent
  end

  def method_or_property(name)
    self["children"].each do |category|
      category["children"].each do |item|
        if item["text"] =~ /^#{name}\(/i
          return NodeWrapper.new(item, self)
        end
      end
    end
    return nil
  end

  def methods()
    methods = []
    self["children"].each do |category|
      category["children"].each do |item|
        methods << item["text"]
      end
    end
    methods
  end
end

class ApexDoc
  def initialize(json_path)
    @json = YAML.load(File.read(json_path))
  end

  def apex_reference()
    @json["toc"][0]["children"].each do |elem|
      return elem if elem["id"] == "apex_reference"
    end
  end

  def namespace(name)
    self.apex_reference()["children"].each do |namespace|
      if namespace["text"] =~ /^#{name}\b/i
        return NamespaceWrapper.new(namespace)
      end
    end
    return nil
  end

  def get_cls(name)
    self.apex_reference()["children"].each do |namespace|
      namespace["children"].each do |cls|
         if cls["text"] =~ /^#{name} Class$/i
           return ClassWrapper.new(cls, NamespaceWrapper.new(namespace))
         end
      end
    end
    return nil
  end

end

def open_browser(node)
  `open #{node.absolute_url}`
end

def main

  paths = ARGV[0].split(/\./)

  is_show_methods = (ARGV[1] == "--show-methods")
  is_show_url = (ARGV[1] == "--show-url")

  apexdoc = ApexDoc.new('apexdoc.json')

  if paths.size == 1
    cls = apexdoc.get_cls(paths[0])
    if is_show_methods
      cls.methods.each do |method|
        puts method
      end
    elsif is_show_url
      puts cls.absolute_url
    else
      open_browser cls
    end
  elsif paths.size == 2
    cls = apexdoc.get_cls(paths[0])
    method = cls.method_or_property(paths[1])
    open_browser method
  elsif paths.size == 3
    namespace = apexdoc.namespace(paths[0])
    cls = namespace.get_cls(paths[1])
    method = cls.method_or_property(paths[2])
    open_browser method
   end

end

main

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
    return self["text"].gsub(/​/, "")
  end
end

class NamespaceWrapper < NodeWrapper

  def initialize(delegatee)
    super delegatee
  end

  def get_cls(name)
    self["children"].each do |cls|
      wrapper = ClassWrapper.new(cls, self)
      if wrapper.name =~ /^#{name} Class$/i
        return wrapper
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
        wrapper = NodeWrapper.new(item, self)
        if wrapper.name =~ /^#{name}\(/i
          return wrapper
        end
      end
    end
    return nil
  end

  def methods()
    methods = []
    self["children"].each do |category|
      category["children"].each do |item|
        wrapper = NodeWrapper.new(item)
        methods << wrapper.name
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
      wrapper = NamespaceWrapper(namespace)
      if wrapper.name =~ /^#{name}\b/i
        return wrapper
      end
    end
    return nil
  end

  def get_cls(name)
    self.apex_reference()["children"].each do |namespace|
      namespace["children"].find do |cls|
         wrapper = ClassWrapper.new(cls, NamespaceWrapper.new(namespace))
         if wrapper.name =~ /^#{name} Class$/
           return wrapper
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

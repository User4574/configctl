#!/usr/bin/env ruby

Signal.trap("INT") { puts ; exit 0 }

class Hash
  def follow(arr)
    ptr = self
    arr.each do |a|
      ptr = ptr[a]
    end
    ptr
  end

  def hash_sub(str)
    nstr = str
    self.each do |name, regexp|
      nstr = nstr.gsub(name, regexp)
    end
    nstr
  end
end

def accept(hash, context, defcontext, defs, formals, noed, line)
  contexts = hash.follow(context).keys - [:match]
  contexts.each do |con|
    if line =~ Regexp.new("^#{defs.hash_sub(con)}$") then
      if noed then
        formals.delete_if do |formal|
          formal.start_with?((defcontext+[line]).join(" "))
        end
      else
        context.push(con)
        defcontext.push(line)
      end
      return true
    else
      next
    end
  end

  matches = hash.follow(context)[:match]
  matches.each do |match|
    if line =~ Regexp.new("^#{defs.hash_sub(match)}$") then
      formal = (defcontext + [line]).join(" ")
      if noed then
        formals.delete(formal)
      else
        formals.push(formal)
        formals.uniq!
      end
      return true
    else
      next
    end
  end

  return false
end

DESC_FILE = File.join(".", "configctl.desc")
DEFS_FILE = File.join(".", "configctl.defs")

defs = {}
hash = {:match => []}
context = []
defcontext = []

formals = []

File.readlines(DEFS_FILE).each do |line|
  line = line.chomp
  la = line.split
  if la.length != 2 then
    puts "Invalid def: \"#{line.chomp}\", too many components, expected \"NAME REGEXP\"."
    exit 1
  end
  defs[la.first] = la.last
end

File.readlines(DESC_FILE).each do |line|
  line = line.chomp
  next if line =~ /^\s*$/
  la = line.split
  if ["end", "exit", "root", "show config"].include?(line) then
    puts "Invalid desc: \"#{line}\", reserved command."
    exit 1
  elsif la.last == "{" then
    la.pop
    con = la.join(" ")
    hash.follow(context)[con] ||= {:match => []}
    context.push(con)
  elsif la == ["}"] then
    context.pop
  else
    com = la.join(" ")
    hash.follow(context)[:match].push(com)
  end
end

loop do
  print "(#{defcontext.join(" ")})> "
  line = gets
  unless line then
    puts
    exit 0
  end
  line = line.chomp

  break if line == "end"
  
  if line == "exit" then
    context.pop
    defcontext.pop
    next
  end

  if line == "root" then
    context = []
    defcontext = []
    next
  end

  if line == "show config" then
    puts "! Generated config:"
    puts formals
    next
  end

  noed = line[0..1] == "no"

  line = line[3..-1] if noed

  accepted = accept(hash, context, defcontext, defs, formals, noed, line)

  if accepted then
    puts noed ? "Removed" : "Accepted"
  else
    puts "Invalid command"
  end
end

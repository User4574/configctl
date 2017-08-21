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
end

def hash_sub(str, defs)
  nstr = str
  defs.each do |name, regexp|
    nstr = nstr.gsub(name, regexp)
  end
  nstr
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
  if ["end", "exit", "root", "show configuration"].include?(line) then
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

  if line == "show configuration" then
    puts "! Generated config:"
    puts formals.uniq
    next
  end

  accepted = false

  contexts = hash.follow(context).keys - [:match]
  contexts.each do |con|
    if line =~ Regexp.new("^#{hash_sub(con, defs)}$") then
      context.push(con)
      defcontext.push(line)
      accepted = true
      break
    else
      next
    end
  end
  next if accepted

  matches = hash.follow(context)[:match]
  matches.each do |match|
    if line =~ Regexp.new("^#{hash_sub(match, defs)}$") then
      formals.push((defcontext + [line]).join(" "))
      puts "Accepted"
      accepted = true
      break
    else
      next
    end
  end
  puts "Invalid command" unless accepted
end

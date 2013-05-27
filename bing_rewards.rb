require "watir-webdriver"
require "watir-webdriver/extensions/alerts"
require "io/console"
require "nokogiri"
require "open-uri"

username       = ""
password       = ""
browser_path   = ""
approve_topics = false

config_file = File.open("settings.conf", "r")
config_file.each do |line|
  split_line = line.chomp.split('=')
  unless split_line[1].nil?
    case split_line[0]
    when "[browser_path]"
      browser_path = split_line[1]
    when "[username]"
      username = split_line[1]
    when "[password]"
      password = split_line[1]
    when "[approve_topics]"
      approve_topics = split_line[1]
    end
  end
end
config_file.close

topics_doc = Nokogiri::HTML(open('http://soovle.com/top'))
topics     = topics_doc.search('div.letter .correction span').to_a.sample(30).collect{|x| x.content}
topics.shuffle!
print "Found 30 Search Topics\n"

if approve_topics
  topics_approved = false
  while !topics_approved
    print "=============\nSEARCH TOPICS\n=============\n"
    topics.each_with_index do |topic, i|
      print "#{(i+1).to_s.rjust(2)}. #{topic}\n"
    end
    print "=============\n=============\n"
    puts "Do you approve these topics? (y|n):"
    if gets.chomp.downcase == "y"
      topics_approved = true
    else
      topics = topics_doc.search('div.letter .correction span').to_a.sample(30).collect{|x| x.content}
      topics.shuffle!
    end
  end
end

unless browser_path == ""
   Selenium::WebDriver::Firefox::Binary.path = browser_path
end
print "Starting Browser\n"
b = Watir::Browser.new
b.goto 'bing.com'
b.span(:text=>"Sign in").when_present.click
b.link(:href, /login\.live/).when_present.click

begin
  login          = b.text_field :type => 'email', :name => 'login'
  pass           = b.text_field :type => 'password', :name => 'passwd'
  sign_in_button = b.input :type => 'submit'

  if username == ""
    puts "Username: "
    username = gets.chomp
  end
  login.set username

  if password == ""
    puts "Password: "
    password = STDIN.noecho {|i| i.gets}.chomp
  end
  pass.set password
  password = ""

  sign_in_button.click
  b.alert.when_present.ok
end while(login.exists? && pass.exists? && sign_in_button.exists?)

topics.each_with_index do |topic, i|
  print "#{(i+1).to_s.rjust(2)}. Searching for #{topic}\n"
  b.text_field(:id=>"sb_form_q").when_present.set(topic)
  b.input(:type=>'submit', :id=>'sb_form_go').click
  sleep 5 # Wait 5 seconds
end

b.close

print "\n==================\nSEARCHES COMPLETED\n==================\n"

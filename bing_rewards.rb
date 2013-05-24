require "watir-webdriver"
require "watir-webdriver/extensions/alerts"
require "io/console"
require "nokogiri"
require "open-uri"

topics_doc = Nokogiri::HTML(open('http://soovle.com/top'))
topics     = topics_doc.search('div.letter .correction span').to_a.sample(30).collect{|x| x.content}
topics.shuffle!

print "Found 30 Search Topics\n"

Selenium::WebDriver::Firefox::Binary.path="C:\\Documents and Settings\\kreisherm\\Local Settings\\Application Data\\Mozilla Firefox\\firefox.exe"

print "Starting Browser\n"
b = Watir::Browser.new
b.goto 'bing.com'
b.span(:text=>"Sign in").when_present.click
b.link(:href, /login\.live/).when_present.click

begin
  login          = b.text_field :type => 'email', :name => 'login'
  pass           = b.text_field :type => 'password', :name => 'passwd'
  sign_in_button = b.input :type => 'submit'

  puts "Username: "
  username = gets.chomp
  login.set username

  puts "Password: "
  password = STDIN.noecho {|i| i.gets}.chomp
  pass.set password
  password = ""

  sign_in_button.click
  b.alert.when_present.ok
end while(login.exists? && pass.exists? && sign_in_button.exists?)

topics.each_with_index do |topic, i|
  print "#{i+1}. Searching for #{topic}\n"
  b.text_field(:id=>"sb_form_q").when_present.set(topic)
  b.input(:type=>'submit', :id=>'sb_form_go').click
end
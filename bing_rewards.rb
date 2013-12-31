require "watir-webdriver"
require "watir-webdriver/extensions/alerts"
require "io/console"
require "nokogiri"
require "open-uri"

username       = ""
password       = ""
browser_path   = ""
approve_topics = false
search_count   = 30
errors 		   = false
searches_per_credit = 3

if ARGV.count == 1 && File.exists?(ARGV[0])
  config_file = File.open(ARGV[0], "r")
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
      when "[search_count]"
        search_count = split_line[1].to_i
      when "[searches_per_credit]"
        searches_per_credit = split_line[1].to_i
      end
    end
  end
  config_file.close
end

def search(credits, searches_per_credit, approve_topics, browser)
  begin
    print "Gathering Searches...\n"
    search_count = credits * searches_per_credit
    topics_doc = Nokogiri::HTML(open('http://soovle.com/top'))
    topics     = topics_doc.search('div.letter .correction span').to_a.sample(search_count).collect{|x| x.content}
    topics.shuffle!
    print "Found #{search_count} Search Topics\n"
  rescue OpenURI::HTTPError => e
    raise IOError, "Unable to find search topics"
  end
  

  if approve_topics
    topics_approved = false
    while !topics_approved
      print "=============\nSEARCH TOPICS\n=============\n"
      topics.each_with_index do |topic, i|
        print "#{(i+1).to_s.rjust(2)}. #{topic}\n"
      end
      print "=============\n=============\n"
      puts "Do you approve these topics? (y|n):"
      if STDIN.gets.chomp.downcase == "y"
        topics_approved = true
      else
        topics = topics_doc.search('div.letter .correction span').to_a.sample(search_count).collect{|x| x.content}
        topics.shuffle!
      end
    end
  end

  begin
    topics.each_with_index do |topic, i|
      print "#{(i+1).to_s.rjust(2)}. Searching for #{topic}\n"
      browser.text_field(:id=>"sb_form_q").when_present.set(topic)
      browser.form(:id=>"sb_form").submit
      sleep 5 # Wait 5 seconds
    end
    print "\n==================\nSEARCHES COMPLETED\n==================\n"
  rescue Watir::Exception::UnknownFormException => e
    print "\n*****\nERROR\n*****\n"
    print "There was an error performing the searches:\n#{e.message}\n"
    raise Watir::Exception::WatirException, "Could not find form"
    errors = true
  rescue Watir::Exception::TimeoutException => e
    print "\n*****\nERROR\n*****\n"
    print "There was an error performing the searches:\n#{e.message}\n"
    raise Watir::Exception::WatirException, "Timeout Occurred"
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

print "Logging In\n"
begin
  login          = b.text_field :type => 'email', :name => 'login'
  pass           = b.text_field :type => 'password', :name => 'passwd'
  sign_in_button = b.input :type => 'submit'

  if username == ""
    puts "Username: "
    username = STDIN.gets.chomp
  end
  login.when_present.set username

  if password == ""
    puts "Password: "
    password = STDIN.noecho {|i| i.gets}.chomp
  end
  pass.set password
  password = ""

  sign_in_button.click
  b.alert.when_present.ok
end while(login.exists? && pass.exists? && sign_in_button.exists?)
print "Logged in as #{username}\n"



print "\n=========\nTODO LIST\n=========\n"
b.goto 'http://www.bing.com/rewards/dashboard'

begin
	todo_ids = []
	todo_list = b.div(:class=>'tileset').ul(:class=>'row')
	todo_list.lis.each do |li|
		not_completed = li.div(:class=>'open-check')
		if not_completed.exists?
			todo_ids << li.link.id
		end
	end
	todo_ids.each do |id|
		link_to_click = b.div(:class=>'tileset').ul(:class=>'row').link(:id=>id)
		print "- #{link_to_click.text}\n"
    if link_to_click.href == "http://www.bing.com/search?q=weather&bnprt=searchandearn"
      progress_tile = link_to_click.div(:class=>'progress')
      progress = progress_tile.text.match(/^(\d+) of (\d+) credits$/)
      link_to_click.click
      b.windows.last.use
      search(progress[2].to_i - progress[1].to_i, searches_per_credit, approve_topics, b)
      b.windows.last.close
    else
      link_to_click.click
      b.windows.last.use
      b.windows.last.close
    end
		b.windows.last.use
	end
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "There was an error processing the todo list:\n#{e.message}\n"
	errors = true
end

b.refresh

begin
	print "\n======\nSTATUS\n======\n"
	balance = b.div(:class=>"user-balance")
	print "#{balance.text}\n"
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "There was an error accessing the balance:\n#{e.message}\n"
	errors = true
end

begin
	print "\n============\nCURRENT GOAL\n============\n"
	goal_title = b.div(:class=>"user-goal-title").link
	progress = b.div(:class=>"user-goal-progress")
	print "#{goal_title.text}\n#{progress.text}\n"
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "Could not find Current Goal:\n#{e.message}\n"
	errors = true
end

b.close

print "* Errors present in run. See log above\n" if errors

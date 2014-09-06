require "io/console"
require "open-uri"
require "bundler/setup"

Bundler.require

$username       = ""
$password       = ""
$approve_topics = false
$errors 	    = false
$mobile_errors  = false
$browser_path   = ""
$mobile         = false
search_count    = 30
searches_per_credit = 3
mobile_searches_per_credit = 2

if ARGV.count == 1 && File.exists?(ARGV[0])
  config_file = File.open(ARGV[0], "r")
  config_file.each do |line|
    split_line = line.chomp.split('=')
    unless split_line[1].nil?
      case split_line[0]
      when "[browser_path]"
        $browser_path = split_line[1]
      when "[username]"
        $username = split_line[1]
      when "[password]"
        $password = split_line[1]
      when "[approve_topics]"
        $approve_topics = split_line[1]
      when "[search_count]"
        search_count = split_line[1].to_i
      when "[searches_per_credit]"
        searches_per_credit = split_line[1].to_i
      end
    end
  end
  config_file.close
end

def search(credits, searches_per_credit, browser)
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


  if $approve_topics
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
	start_link = browser.a(:href => '/search?q=weather&bnprt=searchandearn')
	if start_link.exists?
		start_link.click
	else
		browser.goto 'http://www.bing.com/search?q=weather&bnprt=searchandearn'
	end
    topics.each_with_index do |topic, i|
      print "#{(i+1).to_s.rjust(2)}. Searching for #{topic}\n"
      browser.alert.when_present.ok if browser.alert.exists?
      browser.text_field(:id=>"sb_form_q").when_present.set(topic)
      browser.form(:id=>"sb_form").submit
      sleep 5 # Wait 5 seconds
    end
    print "\n==================\nSEARCHES COMPLETED\n==================\n"
  rescue Watir::Exception::UnknownFormException => e
    print "\n*****\nERROR\n*****\n"
    print "There was an error performing the searches:\n#{e.message}\n"
    raise Watir::Exception::WatirException, "Could not find form"
    $errors = true
  rescue Watir::Exception::TimeoutException => e
    print "\n*****\nERROR\n*****\n"
    print "There was an error performing the searches:\n#{e.message}\n"
    raise Watir::Exception::WatirException, "Timeout Occurred"
  end

end

def todo_list(browser, searches_per_credit)
  begin
  	todo_ids = []
  	browser.divs(:class=>'tileset').each do |offer_div|
  		todo_list = offer_div.ul(:class=>'row')
  		todo_list.lis.each do |li|
  			not_completed = li.div(:class=>'open-check')
  			if not_completed.exists?
  				todo_ids << li.link.id
  			end
  		end
  	end

  	todo_ids.each do |id|
  		link_to_click = browser.link(:id=>id)
  		print "- #{link_to_click.element(:class=>"message").text}\n"
      if ((link_to_click.href == "http://www.bing.com/search?q=weather&bnprt=searchandearn" || 
              link_to_click.href =~ /.*\/search\?q.*/ ||
              link_to_click.href =~ /.*\/news\?q.*/) && !$mobile)
        progress_tile = link_to_click.div(:class=>'progress')
        progress = progress_tile.text.match(/^(\d+) of (\d+) credits$/)
        link_to_click.click
        browser.windows.last.use
        search(progress[2].to_i - progress[1].to_i, searches_per_credit, browser)
        browser.windows.last.close if browser.windows.length > 1
	  elsif (id == 'mobsrch01' || link_to_click.href =~ /.*\/explore\/rewards-mobile.*/) && $mobile
        progress_tile = link_to_click.div(:class=>'progress')
        progress = progress_tile.text.match(/^(\d+) of (\d+) credits$/)
        link_to_click.click
        browser.windows.last.use
        search(progress[2].to_i - progress[1].to_i, searches_per_credit, browser)
        browser.windows.last.close if browser.windows.length > 1
	  elsif (id == 'srchdbl002' || link_to_click.href =~ /.*\/explore\/rewards-searchearn.*/) && !$mobile
        progress_tile = link_to_click.div(:class=>'progress')
        progress = progress_tile.text.match(/^(\d+) of (\d+) credits$/)
        link_to_click.click
        browser.windows.last.use
        search(progress[2].to_i - progress[1].to_i, searches_per_credit, browser)
        browser.windows.last.close if browser.windows.length > 1
      else
        link_to_click.click
		    browser.alert.when_present.ok if browser.alert.exists?
        browser.windows.last.use
        browser.windows.last.close if browser.windows.length > 1
      end
  		browser.windows.last.use
		browser.goto 'http://www.bing.com/rewards/dashboard'
  	end
  rescue Exception => e
  	print "\n*****\nERROR\n*****\n"
  	print "There was an error processing the todo list:\n#{e.message}\n"
  	$errors = true
  end
end

def login(browser)
  begin
    login = browser.text_field :type => 'email', :name => 'login'
    pass = browser.text_field :type => 'password', :name => 'passwd'
    sign_in_button = browser.input :type => 'submit'

    if $username == ""
      puts "Username: "
      $username = STDIN.gets.chomp
    end
    login.when_present.set $username

    if $password == ""
      puts "Password: "
      $password = STDIN.noecho {|i| i.gets}.chomp
    end
    pass.set $password

    sign_in_button.click
    browser.alert.when_present.ok if browser.alert.exists?
  end #while(login.exists? && pass.exists? && sign_in_button.exists?)
  print "Logged in as #{$username}\n"
end




unless $browser_path == ""
   Selenium::WebDriver::Firefox::Binary.path = $browser_path
end


print "\n====================\nSTARTING BING MOBILE\n====================\n"
print "Starting Browser\n"
driver = Webdriver::UserAgent.driver(:agent => :iphone, :orientation => :landscape)
b = Watir::Browser.new driver
$mobile = true
#b.goto 'bing.com/rewards/signin'
#b.span(:text=>"Sign in with your Microsoft account").when_present.click
b.goto 'login.live.com'
#b.link(:id => "WLSignin").when_present.click

login(b)
b.goto 'http://www.bing.com/rewards/dashboard'
todo_list(b, mobile_searches_per_credit)
b.goto 'http://www.bing.com/rewards/dashboard'

begin
	print "\n======\nSTATUS\n======\n"
	balance = b.span(:id => "id_rc")
	print "#{balance.text} Credits Available\n"
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "There was an error accessing the balances:\n#{e.message}\n"
	$errors = true
end

$mobile_errors = true if $errors
$errors = false

print "\n===============\nMOBILE COMPLETE\n===============\n"
b.close

print "\n=====================\nSTARTING BING DESKTOP\n=====================\n"
print "Starting Browser\n"
b = Watir::Browser.new
$mobile = false
b.goto 'login.live.com'

print "Logging In\n"
login(b)

print "\n=========\nTODO LIST\n=========\n"
b.goto 'http://www.bing.com/rewards/dashboard'
todo_list(b, searches_per_credit)

b.refresh

begin
	print "\n======\nSTATUS\n======\n"
	user_level =  b.div(:id => "user-status", :class => "side-tile").element(:class => "level-right").link(:class => "level-label")
	print "#{user_level.text.capitalize} Level\n"
	balance = b.div(:id => "user-status", :class => "side-tile").element(:class => "credits-left").div(:class => "credits")
	print "#{balance.text} Credits Available\n"
	lifetime = b.div(:id => "user-status", :class => "side-tile").element(:class => "credits-right").div(:class => "credits")
	print "#{lifetime.text} Lifetime Credits\n"
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "There was an error accessing the balances:\n#{e.message}\n"
	$errors = true
end

begin
	print "\n============\nCURRENT GOAL\n============\n"
	goal_title = b.link(:class=>"user-goal-title")
	progress = b.div(:class=>"progress-credits")
	percentage = b.div(:class=>"progress-percentage")
	print "#{goal_title.text}\n#{progress.text.sub(' Remove goal', '')} #{percentage.text}\n"
rescue Exception => e
	print "\n*****\nERROR\n*****\n"
	print "Could not find Current Goal:\n#{e.message}\n"
	$errors = true
end
  
b.close

print "\n"
print "MOBILE SUCCESSFUL\n" unless $mobile_errors
print "DESKTOP SUCCESSFUL\n" unless $errors
print "\nRUN COMPLETE AT #{Time.now}\n\n"
print "* Errors present in run. See log above\n" if $errors || $mobile_errors

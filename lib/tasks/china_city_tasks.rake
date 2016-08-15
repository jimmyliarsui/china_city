# desc "Explaining what the task does"
# task :china_city do
#   # Task goes here
# end
require 'json'
require 'pry'
require 'httparty'
require 'nokogiri'

task :generate_postal_codes do

  data = JSON.parse(File.read('db/china_city_areas_2016.08.15.json'))

  result = (data['cities'] + data['districts']).inject({}) do |r, item|
    unless item['postcode']
      text = item['text'].encode('gb2312', 'utf-8')
      url = "http://www.ip138.com/post/search.asp?action=area2zip&area=#{CGI::escape(text)}"
      res = HTTParty.get(url)

      doc = Nokogiri::HTML(res.body)
      links = doc.css("center table .tdc2")
      if links.size > 2
        postcode = links[1].text.match /\d{6}/
        r[item['id']] = postcode
        p "#{item['text']} #{links[1].text} #{postcode}"
      else
        if item['text'] == '北市区'
          r[item['id']] = '071000'
          p "#{item['text']} 071000"
        else
          p "#{item['text']} #{item['id']} not found"
        end
      end
    else
      r[item['id']] = item['postcode']
    end
    r
  end

  File.open('db/postal_codes.json', 'w') do |f|
    f.write JSON.pretty_generate(result)
  end
end

task :generate_sf_support do

  result = ChinaUnit.each(3).inject({}) do |r, street|
    street_unit = ChinaUnit.new(street['id'])
    f = street_unit.full_name
    if street['support_sf'] == true
      r[f] = true
      p f
    end
    r
  end

  File.open('db/sf_support.json', 'w') do |f|
    f.write JSON.pretty_generate(result)
  end

end

require 'tzinfo'
tz = TZInfo::Timezone.get('US/Pacific')
#puts tz.to_local(Time.now)
puts tz.to_local(Time.new(2018, 3, 11, 2, 30, 0, "-08:00"))
puts tz.to_local(Time.now).utc
puts tz.local_time(2018,3,11,2,30,0,0)
puts tz.local_time(2018,3,11,2,30,0,0)

import 'api.dart';
import 'strings_more.dart';

bool get bn => session.lang == 'bn';

/// UI text in English and Bangla. User content (titles, descriptions) is never translated.
String t(String key) {
  final pair = _strings[key] ?? moreStrings[key];
  assert(pair != null, 'missing string: $key');
  return pair == null ? key : (bn ? pair[1] : pair[0]);
}

/// Bilingual names the server sends as xEn/xBn fields, e.g. name(job, 'category').
String name(Map m, String field) => '${m[bn ? '${field}Bn' : '${field}En'] ?? ''}';

const _bnDigits = '০১২৩৪৫৬৭৮৯';
String digits(Object value) =>
    bn ? '$value'.replaceAllMapped(RegExp(r'\d'), (m) => _bnDigits[int.parse(m[0]!)]) : '$value';

String _grouped(num value) {
  final s = value.floor().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// Whole taka, as the web shows it: ৳1,500 or ৳500–800.
String taka(num amount, [num? maximum]) =>
    digits('৳${_grouped(amount)}${maximum != null && maximum > amount ? '–${_grouped(maximum)}' : ''}');

const _unitKey = ['per task', 'per hour', 'per day', 'per month', 'per project'];
String pay(Map job) {
  final unit = job['paymentUnit'];
  final i = unit is int ? unit : const ['Task', 'Hour', 'Day', 'Month', 'Project'].indexOf('$unit');
  return '${taka(job['payAmount'] as num, job['payMaximum'] as num?)} ${t(_unitKey[i < 0 ? 0 : i])}';
}

const _months = [
  ['Jan', 'জানু'], ['Feb', 'ফেব্রু'], ['Mar', 'মার্চ'], ['Apr', 'এপ্রিল'], ['May', 'মে'], ['Jun', 'জুন'],
  ['Jul', 'জুলাই'], ['Aug', 'আগস্ট'], ['Sep', 'সেপ্টে'], ['Oct', 'অক্টো'], ['Nov', 'নভে'], ['Dec', 'ডিসে'],
];

/// Asia/Dhaka (UTC+6, no daylight saving) so a date reads the same as on the web.
DateTime? dhaka(Object? iso) => iso == null ? null : DateTime.parse('$iso').toUtc().add(const Duration(hours: 6));

String date(Object? iso, {bool time = true}) {
  final d = dhaka(iso);
  if (d == null) return t('Not fixed');
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final clock = time ? ', $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}' : '';
  return digits('${d.day} ${_months[d.month - 1][bn ? 1 : 0]}${time ? ' ${d.year}' : ''}$clock');
}

/// "in 3 days", "2 hours ago" — for deadlines and recency.
String relative(Object? iso) {
  if (iso == null) return '';
  final diff = DateTime.parse('$iso').difference(DateTime.now());
  final past = diff.isNegative;
  final a = diff.abs();
  final (n, unit) = a.inDays >= 1
      ? (a.inDays, 'd')
      : a.inHours >= 1
          ? (a.inHours, 'h')
          : (a.inMinutes.clamp(1, 59), 'm');
  final label = {'d': ['day', 'দিন'], 'h': ['hour', 'ঘণ্টা'], 'm': ['min', 'মিনিট']}[unit]!;
  if (bn) return digits(past ? '$n ${label[1]} আগে' : '$n ${label[1]} বাকি');
  return past ? '$n ${label[0]}${n == 1 ? '' : 's'} ago' : 'in $n ${label[0]}${n == 1 ? '' : 's'}';
}

const _strings = <String, List<String>>{
  // Navigation
  'Find work': ['Find work', 'কাজ খুঁজুন'],
  'My work': ['My work', 'আমার কাজ'],
  'To do': ['To do', 'করণীয়'],
  'Me': ['Me', 'আমি'],
  // Find work
  'Work near you, paid fairly': ['Work near you, paid fairly', 'আপনার কাছেই কাজ, ন্যায্য পারিশ্রমিকে'],
  'Hi': ['Hi', 'হ্যালো'],
  'Search work': ['Search jobs, skills, areas', 'কাজ, দক্ষতা বা এলাকা খুঁজুন'],
  'All': ['All', 'সব'],
  'Filters': ['Filters', 'ফিল্টার'],
  'Open now': ['Open now', 'এখন খোলা'],
  'Newest': ['Newest', 'নতুন আগে'],
  'Starting soon': ['Starting soon', 'শীঘ্রই শুরু'],
  'Sort': ['Sort', 'সাজান'],
  'District': ['District', 'জেলা'],
  'Any district': ['Any district', 'যেকোনো জেলা'],
  'Kind of work': ['Kind of work', 'কাজের ধরন'],
  'Remote only': ['Remote only', 'শুধু দূর থেকে'],
  'Show jobs': ['Show jobs', 'কাজ দেখুন'],
  'Clear': ['Clear', 'মুছুন'],
  'No work matches yet': ['No work matches yet', 'এখনো মিলে যাওয়া কোনো কাজ নেই'],
  'Try fewer filters': ['Try fewer filters or another word.', 'কম ফিল্টার বা অন্য শব্দ দিয়ে চেষ্টা করুন।'],
  'Try again': ['Try again', 'আবার চেষ্টা করুন'],
  'You reached the end': ["That's everything for now", 'আপাতত এটুকুই'],
  'Remote': ['Remote', 'দূর থেকে'],
  'Task': ['Task', 'নির্দিষ্ট কাজ'],
  'Shift': ['Shift', 'শিফট'],
  'Recurring': ['Recurring', 'নিয়মিত কাজ'],
  'ShortProject': ['Short project', 'স্বল্পমেয়াদি প্রকল্প'],
  'per task': ['/ task', '/ কাজ'],
  'per hour': ['/ hour', '/ ঘণ্টা'],
  'per day': ['/ day', '/ দিন'],
  'per month': ['/ month', '/ মাস'],
  'per project': ['/ project', '/ প্রকল্প'],
  'Negotiable': ['Negotiable', 'আলোচনা সাপেক্ষ'],
  'Total budget': ['Total budget', 'মোট বাজেট'],
  'filled': ['filled', 'পূর্ণ'],
  'people needed': ['people needed', 'জন দরকার'],
  'Completed': ['Completed', 'সম্পন্ন'],
  'Closed': ['Closed', 'বন্ধ'],
  'Not fixed': ['Not fixed', 'নির্ধারিত নয়'],
  'Apply by': ['Apply by', 'আবেদনের শেষ সময়'],
  // Job detail
  'Starts': ['Starts', 'শুরু'],
  'Ends': ['Ends', 'শেষ'],
  'Where': ['Where', 'কোথায়'],
  'About the work': ['About the work', 'কাজের বিবরণ'],
  'Schedule': ['Schedule', 'সময়সূচি'],
  'Requirements': ['Requirements', 'যোগ্যতা'],
  'Payment timing': ['When you get paid', 'কখন টাকা পাবেন'],
  'Included expenses': ['Expenses covered', 'যে খরচ দেওয়া হবে'],
  'Work conditions': ['Work conditions', 'কাজের পরিবেশ'],
  'Posted by': ['Posted by', 'পোস্ট করেছেন'],
  'jobs completed': ['jobs completed', 'টি কাজ সম্পন্ন'],
  'reviews': ['reviews', 'টি রিভিউ'],
  'New on KazSetu': ['New on KazSetu', 'কাজসেতুতে নতুন'],
  'Reviews': ['Reviews', 'রিভিউ'],
  'Similar work': ['Similar work', 'একই ধরনের কাজ'],
  'Apply': ['Apply', 'আবেদন করুন'],
  'credits': ['credits', 'ক্রেডিট'],
  'credit': ['credit', 'ক্রেডিট'],
  'Sign in to apply': ['Sign in to apply', 'আবেদন করতে সাইন ইন করুন'],
  'View my application': ['View my application', 'আমার আবেদন দেখুন'],
  'This is your post': ['This is your post', 'এটি আপনার পোস্ট'],
  'Not enough credits': ['Not enough credits', 'যথেষ্ট ক্রেডিট নেই'],
  'Applications paused': ['Applications paused', 'আবেদন সাময়িক বন্ধ'],
  'Not accepting applications': ['Not accepting applications', 'আবেদন নেওয়া হচ্ছে না'],
  'Needs a checked licence': ['Needs a checked licence', 'যাচাই করা লাইসেন্স দরকার'],
  'Account not active': ['Account not active', 'অ্যাকাউন্ট সক্রিয় নয়'],
  'Apply for this work': ['Apply for this work', 'এই কাজে আবেদন করুন'],
  'Note to poster': ['Note to the poster (optional)', 'পোস্টদাতার জন্য নোট (ঐচ্ছিক)'],
  'Note hint': ['Say why you are a good fit, in a line or two.', 'কেন আপনি উপযুক্ত, এক-দুই লাইনে লিখুন।'],
  'I am available': ['I am available for the schedule shown', 'দেখানো সময়সূচিতে আমি উপলব্ধ'],
  'Confirm availability': ['Confirm you are available for the schedule shown.', 'দেখানো সময়সূচিতে আপনি উপলব্ধ তা নিশ্চিত করুন।'],
  'Costs': ['Costs', 'খরচ'],
  'You have': ['You have', 'আপনার আছে'],
  'Send application': ['Send application', 'আবেদন পাঠান'],
  'Applied!': ['Application sent!', 'আবেদন পাঠানো হয়েছে!'],
  'Applied body': ['The poster will see it now. We will show updates in My work.', 'পোস্টদাতা এখন এটি দেখবেন। আপডেট "আমার কাজ"-এ দেখাব।'],
  'Refund note': ['Withdraw soon and unseen to get the credit back.', 'দ্রুত এবং দেখার আগে প্রত্যাহার করলে ক্রেডিট ফেরত পাবেন।'],
  // My work
  'Applications': ['Applications', 'আবেদন'],
  'Active': ['Active', 'চলমান'],
  'Past': ['Past', 'পুরনো'],
  'Offer waiting': ['Offer waiting', 'অফার অপেক্ষায়'],
  'No applications yet': ['No applications yet', 'এখনো কোনো আবেদন নেই'],
  'No applications body': ['Find work you like and apply in a minute.', 'পছন্দের কাজ খুঁজে এক মিনিটে আবেদন করুন।'],
  'Browse work': ['Browse work', 'কাজ দেখুন'],
  'Submitted': ['Submitted', 'জমা দেওয়া হয়েছে'],
  'Shortlisted': ['Shortlisted', 'শর্টলিস্টে'],
  'Rejected': ['Not selected', 'নির্বাচিত হয়নি'],
  'Withdrawn': ['Withdrawn', 'প্রত্যাহার করা'],
  'Accepted': ['Accepted', 'গৃহীত'],
  'Offer': ['Offer', 'অফার'],
  'Applied': ['Applied', 'আবেদন'],
  'Hired': ['Hired', 'নিযুক্ত'],
  'You have an offer!': ['You have an offer!', 'আপনি একটি অফার পেয়েছেন!'],
  'Expires': ['Expires', 'মেয়াদ শেষ'],
  'Contact will be shared': ['Contact details are shared when you accept', 'গ্রহণ করলে যোগাযোগের তথ্য বিনিময় হবে'],
  'Accept offer': ['Accept offer', 'অফার গ্রহণ করুন'],
  'Decline': ['Decline', 'প্রত্যাখ্যান'],
  'Review and accept': ['Review the terms', 'শর্তগুলো দেখে নিন'],
  'Accept terms body': ['Accepting creates a work agreement on these terms. Only accept if you will do the work.', 'গ্রহণ করলে এই শর্তে একটি কাজের চুক্তি হবে। কাজটি করবেন নিশ্চিত হলেই গ্রহণ করুন।'],
  'I accept these terms': ['I accept these terms', 'আমি এই শর্তে রাজি'],
  'Decline offer?': ['Decline this offer?', 'অফারটি প্রত্যাখ্যান করবেন?'],
  'Decline body': ['The poster will be told. This cannot be undone.', 'পোস্টদাতাকে জানানো হবে। এটি ফেরানো যাবে না।'],
  'Cancel': ['Cancel', 'বাতিল'],
  'Withdraw application': ['Withdraw application', 'আবেদন প্রত্যাহার'],
  'Withdraw?': ['Withdraw this application?', 'আবেদনটি প্রত্যাহার করবেন?'],
  'Refund until': ['Your credit comes back if you withdraw before', 'এর আগে প্রত্যাহার করলে ক্রেডিট ফেরত পাবেন:'],
  'No refund now': ['The credit will not be refunded now.', 'এখন ক্রেডিট ফেরত দেওয়া হবে না।'],
  'Withdraw': ['Withdraw', 'প্রত্যাহার'],
  'Terms you applied to': ['Terms you applied to', 'যে শর্তে আবেদন করেছেন'],
  'Your note': ['Your note', 'আপনার নোট'],
  'Pay': ['Pay', 'পারিশ্রমিক'],
  'Contact': ['Contact', 'যোগাযোগ'],
  'Open agreement': ['Open the work agreement', 'কাজের চুক্তি খুলুন'],
  'Respond to contact request': ['Respond to the contact request', 'যোগাযোগের অনুরোধের উত্তর দিন'],
  'Opens on web': ['Opens on the website', 'ওয়েবসাইটে খুলবে'],
  'Credit refunded': ['Credit refunded', 'ক্রেডিট ফেরত'],
  // To do
  'All caught up': ['All caught up', 'সব কাজ শেষ'],
  'All caught up body': ['When something needs you — an offer, a review, a meeting — it shows here.', 'অফার, রিভিউ বা মিটিং — আপনার কিছু করার থাকলে এখানে দেখাবে।'],
  'OfferPending': ['Accept or decline an offer', 'অফার গ্রহণ বা প্রত্যাখ্যান করুন'],
  'ContactRequest': ['A poster wants to exchange contact', 'একজন পোস্টদাতা যোগাযোগ বিনিময় করতে চান'],
  'MeetingAcknowledge': ['Confirm the meeting place', 'মিটিংয়ের স্থান নিশ্চিত করুন'],
  'AddMeetingLocation': ['Add a meeting place', 'মিটিংয়ের স্থান যোগ করুন'],
  'CompletionConfirm': ['Confirm the work is done', 'কাজ শেষ হয়েছে নিশ্চিত করুন'],
  'ReviewDue': ['Leave a review', 'রিভিউ দিন'],
  'NewApplicants': ['New applicants to review', 'নতুন আবেদনকারী দেখুন'],
  'ChangesRequested': ['Changes requested on your post', 'আপনার পোস্টে পরিবর্তন চাওয়া হয়েছে'],
  // Me
  'Credits': ['Credits', 'ক্রেডিট'],
  'Credits explainer': ['Each application uses credits. New credits arrive every month.', 'প্রতিটি আবেদনে ক্রেডিট লাগে। প্রতি মাসে নতুন ক্রেডিট আসে।'],
  'History': ['History', 'ইতিহাস'],
  'SignupGrant': ['Welcome credits', 'স্বাগত ক্রেডিট'],
  'MonthlyGrant': ['Monthly credits', 'মাসিক ক্রেডিট'],
  'DiscretionaryGrant': ['Bonus credits', 'বোনাস ক্রেডিট'],
  'ApplicationDebit': ['Applied to work', 'কাজে আবেদন'],
  'ApplicationRefund': ['Refund', 'ফেরত'],
  'OperatorCorrection': ['Correction', 'সংশোধন'],
  'Language': ['Language', 'ভাষা'],
  'Post work': ['Post work you need done', 'কাজ পোস্ট করুন'],
  'Post work body': ['Posting and managing your posts opens the website.', 'পোস্ট করা ও পরিচালনা ওয়েবসাইটে খুলবে।'],
  'Edit profile': ['Edit profile', 'প্রোফাইল সম্পাদনা'],
  'Help': ['Help & support', 'সাহায্য ও সহায়তা'],
  'Sign out': ['Sign out', 'সাইন আউট'],
  'Sign out?': ['Sign out of KazSetu?', 'কাজসেতু থেকে সাইন আউট করবেন?'],
  // Auth
  'Sign in': ['Sign in', 'সাইন ইন'],
  'Create account': ['Create account', 'অ্যাকাউন্ট খুলুন'],
  'Welcome back': ['Welcome back', 'আবার স্বাগতম'],
  'Join KazSetu': ['Join KazSetu', 'কাজসেতুতে যোগ দিন'],
  'Join body': ['Free to join. You get credits to apply right away.', 'যোগ দেওয়া ফ্রি। এখনই আবেদনের জন্য ক্রেডিট পাবেন।'],
  'Sign in body': ['Apply for work and track every offer.', 'কাজে আবেদন করুন, প্রতিটি অফার দেখুন।'],
  'Phone or username': ['Phone number or username', 'ফোন নম্বর বা ইউজারনেম'],
  'Phone number': ['Phone number', 'ফোন নম্বর'],
  'Your name': ['Name to show publicly', 'যে নাম সবাই দেখবে'],
  'Password': ['Password', 'পাসওয়ার্ড'],
  'Password hint': ['At least 6 characters, including a digit', 'কমপক্ষে ৬ অক্ষর, একটি সংখ্যাসহ'],
  'Show password': ['Show password', 'পাসওয়ার্ড দেখান'],
  'Hide password': ['Hide password', 'পাসওয়ার্ড লুকান'],
  'Accept terms': ['I am 18 or older and accept the terms', 'আমার বয়স ১৮ বা তার বেশি এবং আমি শর্তাবলি মানছি'],
  'Read terms': ['Read the terms', 'শর্তাবলি পড়ুন'],
  'Required': ['Required', 'আবশ্যক'],
  'No account?': ['New here?', 'নতুন?'],
  'Have account?': ['Already have an account?', 'আগে থেকেই অ্যাকাউন্ট আছে?'],
  'Forgot password?': ['Forgot password?', 'পাসওয়ার্ড ভুলে গেছেন?'],
  'Sign in to see this': ['Sign in to see your work', 'আপনার কাজ দেখতে সাইন ইন করুন'],
  'Sign in prompt body': ['Applications, offers and things that need you — all in one place.', 'আবেদন, অফার আর আপনার করণীয় — সব এক জায়গায়।'],
};

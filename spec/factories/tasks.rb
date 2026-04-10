FactoryBot.define do
  factory :task do
    association :user
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    status { :pending }
    due_date { Faker::Date.forward(days: 30) }
  end
end

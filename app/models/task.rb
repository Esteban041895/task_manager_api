class Task < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  validates :title, presence: true
  validates :status, presence: true

  scope :for_user, ->(user) { where(user: user) }
end

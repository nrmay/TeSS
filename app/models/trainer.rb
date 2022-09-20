require 'i18n_data'

# define model for Trainer as subset of Profile
class Trainer < Profile

  after_update_commit :reindex
  after_destroy_commit :reindex


  extend FriendlyId
  friendly_id :full_name, use: :slugged

  include Searchable
  include HasSuggestions

  if TeSS::Config.solr_enabled
    # :nocov:
    searchable do
      # full text search fields
      text :description
      text :full_name
      text :location
      # sort title
      string :sort_title do
        full_name.downcase
      end
      # other fields
      integer :user_id
      string :description
      string :full_name
      string :location
      time :updated_at
      boolean :public
    end
    # :nocov:
  end

  update_suggestions(:activity, :expertise_academic, :expertise_technical,
                     :interest)

  def self.facet_fields
    field_list = %w( location experience expertise_academic expertise_technical
                     fields interest activity language )
  end

  def should_generate_new_friendly_id?
    firstname_changed? or surname_changed?
  end

  def language_label_by_key(key)
    if key and !key.nil?
      I18nData.languages.each do |lang|
        return lang[1] if lang[0] == key
      end
    end
  end

  def languages_from_keys(keys)
    labels = []
    keys.each { |key| labels << language_label_by_key(key) }
    return labels
  end

  def self.finder_needs_type_condition?
    true
  end

end

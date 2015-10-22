require 'spec_helper'
require 'languages'

describe Languages::Language do
  describe ".by_extension" do
    it "returns an array of candidate languages by extension" do
      ruby_language = described_class.find_by_name("Ruby")

      expect(described_class.by_extension('.rb')).to eq([ruby_language])
    end
  end
end

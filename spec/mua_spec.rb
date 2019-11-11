RSpec.describe Mua do
  it "has a version number" do
    expect(Mua.version).to match(/\A\d+\.\d+\.\d+/)
  end
end

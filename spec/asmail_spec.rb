RSpec.describe ASMail do
  it "has a version number" do
    expect(ASMail.version).to match(/\A\d+\.\d+\.\d+/)
  end
end

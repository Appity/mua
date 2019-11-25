RSpec.describe Mua::EmailAddress do
  it 'can validate RFC822 compliant envelope addresses' do
    expect_mapping(
      'test@example.com' => true,
      '@example.com' => false,
      '@' => false,
      nil => false,
      false => false,
      'true@false' => true,
      'Example <address@example.com>' => false
    ) do |addr|
      Mua::EmailAddress.valid?(addr)
    end
  end
end

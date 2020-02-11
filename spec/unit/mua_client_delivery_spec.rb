require 'ostruct'

RSpec.describe Mua::Client::Delivery, type: :reactor do
  before do
    @message = OpenStruct.new(data: 'From: example@pistachio.email')
  end

  it 'can yield pending a delivery result when inside an Async block' do
    delivery = Mua::Client::Delivery.new(@message)

    delivery_task = Async do
      delivery.wait
    end

    result = Mua::Client::DeliveryResult.new(
      message: @message,
      result_code: 'SMTP_250',
      result_message: 'OK',
      delivered: true
    )

    Async do
      delivery.resolve(result)
    end

    delivery_result = delivery_task.wait

    expect(delivery_result).to be(result)
  end
end

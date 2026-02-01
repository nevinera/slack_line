module StubbedInstantiation
  def stubbed_instantiation(klass, class_method = :new, **methods)
    instance_double(klass, **methods).tap do |stub|
      allow(klass).to receive(class_method).and_return(stub)
    end
  end
end

RSpec.configure do |config|
  config.include StubbedInstantiation
end

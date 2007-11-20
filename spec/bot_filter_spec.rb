require File.dirname(__FILE__) + '/spec_helper'
require 'bot_filter'

describe BotFilter, 'as a class' do
  should 'provide a way to register a new filter' do
    mock_class = mock('BotFilter subclass')
    BotFilter.register(:filt => mock_class)
    BotFilter.kinds.should include(:filt)
  end
  
  should 'provide a way to get the list of known filters' do
    BotFilter.kinds.should respond_to(:each)
  end
  
  should 'provide a way to clear the list of known filters' do
    mock_class = mock('BotFilter subclass')
    BotFilter.register(:testing => mock_class)
    BotFilter.kinds.should include(:testing)
    BotFilter.clear_kinds
    BotFilter.kinds.should be_empty
  end
  
  should 'provide the list of known filters in a stable order' do
    mock_class = mock('BotFilter subclass')
    kinds = [:filt, :test, :blah, :stuff, :hello]
    kinds.each { |kind|  BotFilter.register(kind => mock_class) }
    BotFilter.kinds.should == kinds.sort_by { |k|  k.to_s }
  end
end

def setup_filter_chain
  @data = %w[a b c d e]
  @filters = Array.new(@data.size - 1) { |i|  { "name_#{@data[i]}".to_sym => stub("class #{@data[i]}") } }
  @objects = []
  @filters.each_index do |i|
    name = "name_#{@data[i]}".to_sym
    filter = @filters[i][name]
    obj = stub('object #{@data[i]}')
    @objects.push(obj)
    obj.stubs(:process).with(@data[i]).returns(@data[i+1])
    filter.stubs(:new).returns(obj)
  end
  
  @filters.each do |f|
    f.each_pair { |k, v|  BotFilter.register(k => v) }
  end
end

describe BotFilter, 'when processing' do
  before :each do
    @filter = BotFilter.new
    BotFilter.clear_kinds
  end
  
  should 'require data' do
    lambda { @filter.process }.should raise_error(ArgumentError)
  end
  
  should 'accept data' do
    lambda { @filter.process('hey hey hey') }.should_not raise_error(ArgumentError)
  end
  
  should 'pass through the filter chain and return the result' do
    setup_filter_chain
    @objects.each_with_index { |o, i|  o.expects(:process).with(@data[i]).returns(@data[i+1]) }
    @filter.process(@data.first).should == @data.last
  end
  
  should 'stop the filter chain and return nil if any filter returns a false value' do
    setup_filter_chain
    target_index = @objects.size / 2
    @objects.each_with_index do |o, i|
      if i < target_index
        o.expects(:process).with(@data[i]).returns(@data[i+1])
      elsif i == target_index
        o.expects(:process).with(@data[i]).returns(false)
      else
        o.expects(:process).never
      end
    end
    @filter.process(@data.first).should be_nil
  end
end

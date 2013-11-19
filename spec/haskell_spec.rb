require 'rspec'
require 'guard/haskell'

describe "monkey patching" do
  context String do
    context "strip_lowercase_directories" do
      it "works on empty string" do
        "".strip_lowercase_directories.should == ""
      end

      it "works on string without lowercase directory prefixes" do
        "Foo".strip_lowercase_directories.should == "Foo"
      end

      it "works on string with lowercase directory prefix" do
        "foo/Bar".strip_lowercase_directories.should == "Bar"
      end

      it "works on string with multiple lowercase directory prefixes" do
        "foo/bar/Baz".strip_lowercase_directories.should == "Baz"
      end
    end

    context "path_to_module_name" do
      it "works on string without path separators" do
        "Foo".path_to_module_name.should == "Foo"
      end

      it "works on string with path separators" do
        "Foo/Bar/Baz".path_to_module_name.should == "Foo.Bar.Baz"
      end
    end
  end
end

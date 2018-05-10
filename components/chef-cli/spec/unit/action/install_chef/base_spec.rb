
require "spec_helper"
require "chef-cli/action/install_chef"

RSpec.describe ChefCLI::Action::InstallChef::Base do
  let(:mock_os_name) { "mock" }
  let(:mock_os_family) { "mock" }
  let(:mock_os_release ) { "unknown" }
  let(:mock_opts) do
    {
      name: mock_os_name,
      family: mock_os_family,
      release: mock_os_release,
      arch: "x86_64",
    }
  end
  let(:target_host) do
    ChefCLI::TargetHost.new("mock://user1:password1@localhost")
  end

  let(:reporter) do
    ChefCLI::MockReporter.new
  end

  subject(:install) do
    ChefCLI::Action::InstallChef::Base.new(target_host: target_host,
                                           reporter: reporter) end
  before do
    target_host.connect!
    target_host.backend.mock_os(mock_opts)
  end

  context "#perform_action" do
    context "when chef is already installed on target at the correct minimum version" do
      before do
        expect(install.target_host).to receive(:installed_chef_version).and_return ChefCLI::Action::InstallChef::Base::MIN_CHEF_VERSION
      end
      it "notifies of success and takes no further action" do
        expect(install).not_to receive(:perform_local_install)
        install.perform_action
      end
    end

    context "when chef is already installed on target at a version that's too low" do
      before do
        expect(install.target_host).to receive(:installed_chef_version).
          and_return Gem::Version.new("12.1.1")
      end
      # 2018-05-10  pended until we determine how we want auto-upgrades to behave
      xit "performs the upgrade" do
        expect(install).to receive(:perform_local_install)
        install.perform_action
      end
    end

    context "when chef is not already installed on target" do
      before do
        expect(install.target_host).to receive(:installed_chef_version).
          and_raise ChefCLI::TargetHost::ChefNotInstalled.new
      end

      context "on windows" do
        let(:mock_os_name) { "Windows_Server" }
        let(:mock_os_family) { "windows" }
        let(:mock_os_releae) { "10.0.1" }

        it "should invoke perform_local_install" do
          expect(install).to receive(:perform_local_install)
          install.perform_action
        end
      end

      context "on anything else" do
        let(:mock_os_name) { "Ubuntu" }
        let(:mock_os_family) { "debian" }
        it "should invoke perform_local_install" do
          expect(install).to receive(:perform_local_install)
          install.perform_action
        end
      end
    end
  end
  context "#perform_local_install" do
    let(:artifact) { double("artifact") }
    let(:package_url) { "https://chef.io/download/package/here" }
    before do
      allow(artifact).to receive(:url).and_return package_url
    end

    it "performs the steps necessary to perform an installation" do
      expect(install).to receive(:lookup_artifact).and_return artifact
      expect(install).to receive(:download_to_workstation).with(package_url) .and_return "/local/path"
      expect(install).to receive(:upload_to_target).with("/local/path").and_return("/remote/path")
      expect(install).to receive(:install_chef_to_target).with("/remote/path")

      install.perform_local_install
    end
  end
end
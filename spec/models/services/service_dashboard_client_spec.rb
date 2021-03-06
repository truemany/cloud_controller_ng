require 'spec_helper'

module VCAP::CloudController
  describe ServiceDashboardClient do
    let(:service_broker) { ServiceBroker.make }
    let(:other_broker) { ServiceBroker.make }
    let(:uaa_id) { 'claimed_client_id' }

    describe '.find_clients_claimed_by_broker' do
      before do
        ServiceDashboardClient.claim_client_for_broker('client-1', service_broker)
        ServiceDashboardClient.claim_client_for_broker('client-2', other_broker)
        ServiceDashboardClient.claim_client_for_broker('client-3', service_broker)
      end

      it 'returns all clients claimed by the broker' do
        results = ServiceDashboardClient.find_clients_claimed_by_broker(service_broker)
        expect(results).to have(2).entries
        expect(results.map(&:uaa_id)).to match_array ['client-1', 'client-3']
      end
    end

    describe '.client_claimed_by_broker?' do
      context 'when broker has claimed the client' do
        before do
          ServiceDashboardClient.make(uaa_id: uaa_id, service_broker: service_broker)
        end
        
        it 'returns true' do
          expect(ServiceDashboardClient.client_claimed_by_broker?(uaa_id, service_broker)).to be_true
        end
      end

      context 'when a different broker has claimed the client' do     
        before do
          ServiceDashboardClient.make(uaa_id: uaa_id, service_broker: other_broker)
        end
        
        it 'returns false' do
          expect(ServiceDashboardClient.client_claimed_by_broker?(uaa_id, service_broker)).to be_false
        end
      end

      context 'when no broker has claimed the client' do
        it 'returns false' do
          expect(ServiceDashboardClient.client_claimed_by_broker?(uaa_id, service_broker)).to be_false
        end
      end
    end

    describe '.claim_client_for_broker' do
      context 'when the client is unclaimed' do
        it 'claims the client for the broker' do
          expect {
            ServiceDashboardClient.claim_client_for_broker(uaa_id, service_broker)
          }.to change {
            ServiceDashboardClient.client_claimed_by_broker?(uaa_id, service_broker)
          }.to(true)
        end
      end

      context 'when the client is already claimed' do
        before do
          ServiceDashboardClient.claim_client_for_broker(uaa_id, other_broker)
        end

        it 'raises an exception' do
          expect {
            ServiceDashboardClient.claim_client_for_broker(uaa_id, service_broker)
          }.to raise_exception(Sequel::ValidationFailed)
        end
      end
    end

    describe '.remove_claim_on_client' do
      before do
        ServiceDashboardClient.claim_client_for_broker(uaa_id, service_broker)
      end

      it 'removes the claim' do
        expect {
          ServiceDashboardClient.remove_claim_on_client(uaa_id)
        }.to change { ServiceDashboardClient.client_claimed_by_broker?(uaa_id, service_broker)}.to(false)
      end
    end

    describe 'validation' do
      def build_service_dashboard_client(attrs={})
        if attrs.has_key?(:service_broker)
          ServiceDashboardClient.make_unsaved(attrs)
        else
          ServiceDashboardClient.make_unsaved(attrs.merge(service_broker: service_broker))
        end
      end
      
      context 'when all fields are valid' do
        let(:client) { build_service_dashboard_client }

        it 'is valid' do
          expect(client).to be_valid
        end
      end

      context 'when the uaa id is nil' do
        let(:client_without_uaa_id) { build_service_dashboard_client(uaa_id: nil) }
        it 'is not valid' do
          expect(client_without_uaa_id).not_to be_valid
        end
      end

      context 'when the uaa id is blank' do
        let(:client_without_uaa_id) { build_service_dashboard_client(uaa_id: '') }
        it 'is not valid' do
          expect(client_without_uaa_id).not_to be_valid
        end
      end

      context 'when the uaa id is not unique' do
        before { ServiceDashboardClient.make(uaa_id: 'already_taken') }
        let(:client_with_duplicate_uaa_id) { build_service_dashboard_client(uaa_id: 'already_taken') }

        it 'is not valid' do
          expect(client_with_duplicate_uaa_id).not_to be_valid
        end
      end

      context "when the service broker is nil" do
        let(:client_without_service_id_on_broker) { build_service_dashboard_client(service_broker: nil) }
        it 'is not valid' do
          expect(client_without_service_id_on_broker).not_to be_valid
        end
      end
    end
  end
end

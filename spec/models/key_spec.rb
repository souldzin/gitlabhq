# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Key, :mailer do
  describe "Associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "Validation" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }

    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_length_of(:key).is_at_most(5000) }
    it { is_expected.to allow_value(attributes_for(:rsa_key_2048)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:rsa_key_4096)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:rsa_key_5120)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:rsa_key_8192)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:dsa_key_2048)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:ecdsa_key_256)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:ed25519_key_256)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:ecdsa_sk_key_256)[:key]).for(:key) }
    it { is_expected.to allow_value(attributes_for(:ed25519_sk_key_256)[:key]).for(:key) }
    it { is_expected.not_to allow_value('foo-bar').for(:key) }

    context 'key format' do
      let(:key) { build(:key) }

      it 'does not allow the key that begins with an algorithm name that is unsupported' do
        key.key = 'unsupported-ssh-rsa key'

        key.valid?

        expect(key.errors.of_kind?(:key, :invalid)).to eq(true)
      end

      Gitlab::SSHPublicKey.supported_algorithms.each do |supported_algorithm|
        it "allows the key that begins with supported algorithm name '#{supported_algorithm}'" do
          key.key = "#{supported_algorithm} key"

          key.valid?

          expect(key.errors.of_kind?(:key, :invalid)).to eq(false)
        end
      end
    end
  end

  describe "Methods" do
    let(:user) { create(:user) }

    it { is_expected.to respond_to :projects }
    it { is_expected.to respond_to :publishable_key }

    describe "#publishable_keys" do
      it 'replaces SSH key comment with simple identifier of username + hostname' do
        expect(build(:key, user: user).publishable_key).to include("#{user.name} (#{Gitlab.config.gitlab.host})")
      end
    end

    describe "#update_last_used_at" do
      it 'updates the last used timestamp' do
        key = build(:key)
        service = double(:service)

        expect(Keys::LastUsedService).to receive(:new)
          .with(key)
          .and_return(service)

        expect(service).to receive(:execute)

        key.update_last_used_at
      end
    end
  end

  describe 'scopes' do
    describe '.for_user' do
      let(:user_1) { create(:user) }
      let(:key_of_user_1) { create(:personal_key, user: user_1) }

      before do
        create_list(:personal_key, 2, user: create(:user))
      end

      it 'returns keys of the specified user only' do
        expect(described_class.for_user(user_1)).to contain_exactly(key_of_user_1)
      end
    end

    describe '.order_last_used_at_desc' do
      it 'sorts by last_used_at descending, with null values at last' do
        key_1 = create(:personal_key, last_used_at: 7.days.ago)
        key_2 = create(:personal_key, last_used_at: nil)
        key_3 = create(:personal_key, last_used_at: 2.days.ago)

        expect(described_class.order_last_used_at_desc)
          .to eq([key_3, key_1, key_2])
      end
    end

    context 'expiration scopes' do
      let_it_be(:user) { create(:user) }
      let_it_be(:expired_today_not_notified) { create(:key, :expired_today, user: user) }
      let_it_be(:expired_today_already_notified) { create(:key, :expired_today, user: user, expiry_notification_delivered_at: Time.current) }
      let_it_be(:expired_yesterday) { create(:key, :expired, user: user) }
      let_it_be(:expiring_soon_unotified) { create(:key, expires_at: 3.days.from_now, user: user) }
      let_it_be(:expiring_soon_notified) { create(:key, expires_at: 4.days.from_now, user: user, before_expiry_notification_delivered_at: Time.current) }
      let_it_be(:future_expiry) { create(:key, expires_at: 1.month.from_now, user: user) }

      describe '.expired_today_and_not_notified' do
        it 'returns keys that expire today and have not been notified' do
          expect(described_class.expired_today_and_not_notified).to contain_exactly(expired_today_not_notified)
        end
      end

      describe '.expiring_soon_and_not_notified' do
        it 'returns keys that will expire soon' do
          expect(described_class.expiring_soon_and_not_notified).to contain_exactly(expiring_soon_unotified)
        end
      end
    end
  end

  context 'validation of uniqueness (based on fingerprint uniqueness)' do
    let(:user) { create(:user) }

    it 'accepts the key once' do
      expect(build(:rsa_key_4096, user: user)).to be_valid
    end

    it 'does not accept the exact same key twice' do
      first_key = create(:rsa_key_4096, user: user)

      expect(build(:key, user: user, key: first_key.key)).not_to be_valid
    end

    it 'does not accept a duplicate key with a different comment' do
      first_key = create(:rsa_key_4096, user: user)
      duplicate = build(:key, user: user, key: first_key.key)
      duplicate.key << ' extra comment'

      expect(duplicate).not_to be_valid
    end
  end

  context 'fingerprint generation' do
    it 'generates both md5 and sha256 fingerprints' do
      key = build(:rsa_key_4096)

      expect(key).to be_valid
      expect(key.fingerprint).to be_kind_of(String)
      expect(key.fingerprint_sha256).to be_kind_of(String)
    end

    context 'with FIPS mode', :fips_mode do
      it 'generates only sha256 fingerprint' do
        key = build(:rsa_key_4096)

        expect(key).to be_valid
        expect(key.fingerprint).to be_nil
        expect(key.fingerprint_sha256).to be_kind_of(String)
      end
    end
  end

  context "validate it is a fingerprintable key" do
    it "accepts the fingerprintable key" do
      expect(build(:key)).to be_valid
    end

    it 'rejects the unfingerprintable key (not a key)' do
      expect(build(:key, key: 'ssh-rsa an-invalid-key==')).not_to be_valid
    end

    where(:factory, :characters, :expected_sections) do
      [
        [:key,                 ["\n", "\r\n"], 3],
        [:key,                 [' ', ' '],     3],
        [:key_without_comment, [' ', ' '],     2]
      ]
    end

    with_them do
      let!(:key) { create(factory) } # rubocop:disable Rails/SaveBang
      let!(:original_fingerprint) { key.fingerprint }
      let!(:original_fingerprint_sha256) { key.fingerprint_sha256 }

      it 'accepts a key with blank space characters after stripping them' do
        modified_key = key.key.insert(100, characters.first).insert(40, characters.last)
        _, content = modified_key.split

        key.update!(key: modified_key)

        expect(key).to be_valid
        expect(key.key.split.size).to eq(expected_sections)

        expect(content).not_to match(/\s/)
        expect(original_fingerprint).to eq(key.fingerprint)
        expect(original_fingerprint).to eq(key.fingerprint_md5)
        expect(original_fingerprint_sha256).to eq(key.fingerprint_sha256)
      end
    end
  end

  context 'validate it meets key restrictions' do
    where(:factory, :minimum, :result) do
      forbidden = ApplicationSetting::FORBIDDEN_KEY_VALUE

      [
        [:rsa_key_2048,       0, true],
        [:dsa_key_2048,       0, true],
        [:ecdsa_key_256,      0, true],
        [:ed25519_key_256,    0, true],
        [:ecdsa_sk_key_256,   0, true],
        [:ed25519_sk_key_256, 0, true],

        [:rsa_key_2048, 1024, true],
        [:rsa_key_2048, 2048, true],
        [:rsa_key_2048, 4096, false],

        [:dsa_key_2048, 1024, true],
        [:dsa_key_2048, 2048, true],
        [:dsa_key_2048, 4096, false],

        [:ecdsa_key_256, 256, true],
        [:ecdsa_key_256, 384, false],

        [:ed25519_key_256, 256, true],
        [:ed25519_key_256, 384, false],

        [:ecdsa_sk_key_256, 256, true],
        [:ecdsa_sk_key_256, 384, false],

        [:ed25519_sk_key_256, 256, true],
        [:ed25519_sk_key_256, 384, false],

        [:rsa_key_2048,       forbidden, false],
        [:dsa_key_2048,       forbidden, false],
        [:ecdsa_key_256,      forbidden, false],
        [:ed25519_key_256,    forbidden, false],
        [:ecdsa_sk_key_256,   forbidden, false],
        [:ed25519_sk_key_256, forbidden, false]
      ]
    end

    with_them do
      subject(:key) { build(factory) }

      before do
        stub_application_setting("#{key.public_key.type}_key_restriction" => minimum)
      end

      it { expect(key.valid?).to eq(result) }
    end
  end

  context 'callbacks' do
    let(:key) { build(:personal_key) }

    context 'authorized keys file is enabled' do
      before do
        stub_application_setting(authorized_keys_enabled: true)
      end

      it 'adds new key to authorized_file' do
        allow(AuthorizedKeysWorker).to receive(:perform_async)

        key.save!

        # Check after the fact so we have access to Key#id
        expect(AuthorizedKeysWorker).to have_received(:perform_async).with(:add_key, key.shell_id, key.key)
      end

      it 'removes key from authorized_file' do
        key.save!

        expect(AuthorizedKeysWorker).to receive(:perform_async).with(:remove_key, key.shell_id)

        key.destroy!
      end
    end

    context 'authorized_keys file is disabled' do
      before do
        stub_application_setting(authorized_keys_enabled: false)
      end

      it 'does not add the key on creation' do
        expect(AuthorizedKeysWorker).not_to receive(:perform_async)

        key.save!
      end

      it 'does not remove the key on destruction' do
        key.save!

        expect(AuthorizedKeysWorker).not_to receive(:perform_async)

        key.destroy!
      end
    end
  end

  describe '#key=' do
    let(:valid_key) do
      "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAiPWx6WM4lhHNedGfBpPJNPpZ7yKu+dnn1SJejgt4596k6YjzGGphH2TUxwKzxcKDKKezwkpfnxPkSMkuEspGRt/aZZ9wa++Oi7Qkr8prgHc4soW6NUlfDzpvZK2H5E7eQaSeP3SAwGmQKUFHCddNaP0L+hM7zhFNzjFvpaMgJw0= dummy@gitlab.com"
    end

    it 'strips white spaces' do
      expect(described_class.new(key: " #{valid_key} ").key).to eq(valid_key)
    end

    it 'invalidates the public_key attribute' do
      key = build(:key)

      original = key.public_key
      key.key = valid_key

      expect(original.key_text).not_to be_nil
      expect(key.public_key.key_text).to eq(valid_key)
    end
  end

  describe '#refresh_user_cache', :use_clean_rails_memory_store_caching do
    context 'when the key belongs to a user' do
      it 'refreshes the keys count cache for the user' do
        expect_any_instance_of(Users::KeysCountService)
          .to receive(:refresh_cache)
          .and_call_original

        key = create(:personal_key)

        expect(Users::KeysCountService.new(key.user).count).to eq(1)
      end
    end

    context 'when the key does not belong to a user' do
      it 'does nothing' do
        expect_any_instance_of(Users::KeysCountService)
          .not_to receive(:refresh_cache)

        create(:key)
      end
    end
  end
end

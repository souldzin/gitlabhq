# frozen_string_literal: true
require "spec_helper"

RSpec.describe Pajamas::AlertComponent, :aggregate_failures, type: :component do
  context 'slots' do
    let_it_be(:body) { 'Alert body' }
    let_it_be(:actions) { 'Alert actions' }

    before do
      render_inline described_class.new do |c|
        c.body { body }
        c.actions { actions }
      end
    end

    it 'renders alert body' do
      expect(rendered_component).to have_content(body)
    end

    it 'renders actions' do
      expect(rendered_component).to have_content(actions)
    end
  end

  context 'with defaults' do
    before do
      render_inline described_class.new
    end

    it 'does not set a title' do
      expect(rendered_component).not_to have_selector('.gl-alert-title')
      expect(rendered_component).to have_selector('.gl-alert-icon-no-title')
    end

    it 'renders the default variant' do
      expect(rendered_component).to have_selector('.gl-alert-info')
      expect(rendered_component).to have_selector("[data-testid='information-o-icon']")
      expect(rendered_component).not_to have_selector('.gl-alert-no-icon')
    end

    it 'renders a dismiss button' do
      expect(rendered_component).to have_selector('.gl-dismiss-btn.js-close')
      expect(rendered_component).to have_selector("[data-testid='close-icon']")
      expect(rendered_component).not_to have_selector('.gl-alert-not-dismissible')
    end
  end

  context 'with custom options' do
    context 'with simple options' do
      before do
        render_inline described_class.new(
          title: '_title_',
          alert_class: '_alert_class_',
          alert_data: {
            feature_id: '_feature_id_',
            dismiss_endpoint: '_dismiss_endpoint_'
          }
        )
      end

      it 'sets the title' do
        expect(rendered_component).to have_selector('.gl-alert-title')
        expect(rendered_component).to have_content('_title_')
        expect(rendered_component).not_to have_selector('.gl-alert-icon-no-title')
      end

      it 'sets the alert_class' do
        expect(rendered_component).to have_selector('._alert_class_')
      end

      it 'sets the alert_data' do
        expect(rendered_component).to have_selector('[data-feature-id="_feature_id_"][data-dismiss-endpoint="_dismiss_endpoint_"]')
      end
    end

    context 'with dismissible disabled' do
      before do
        render_inline described_class.new(dismissible: false)
      end

      it 'has the "not dismissible" class' do
        expect(rendered_component).to have_selector('.gl-alert-not-dismissible')
      end

      it 'does not render the dismiss button' do
        expect(rendered_component).not_to have_selector('.gl-dismiss-btn.js-close')
        expect(rendered_component).not_to have_selector("[data-testid='close-icon']")
      end
    end

    context 'with the icon hidden' do
      before do
        render_inline described_class.new(show_icon: false)
      end

      it 'has the hidden icon class' do
        expect(rendered_component).to have_selector('.gl-alert-no-icon')
      end

      it 'does not render the icon' do
        expect(rendered_component).not_to have_selector('.gl-alert-icon')
        expect(rendered_component).not_to have_selector("[data-testid='information-o-icon']")
      end
    end

    context 'with dismissible content' do
      before do
        render_inline described_class.new(
          close_button_class: '_close_button_class_',
          close_button_data: {
            testid: '_close_button_testid_'
          }
        )
      end

      it 'does not have "not dismissible" class' do
        expect(rendered_component).not_to have_selector('.gl-alert-not-dismissible')
      end

      it 'renders a dismiss button and data' do
        expect(rendered_component).to have_selector('.gl-dismiss-btn.js-close._close_button_class_')
        expect(rendered_component).to have_selector("[data-testid='close-icon']")
        expect(rendered_component).to have_selector('[data-testid="_close_button_testid_"]')
      end
    end

    context 'with setting variant type' do
      where(:variant) { [:warning, :success, :danger, :tip] }

      before do
        render_inline described_class.new(variant: variant)
      end

      with_them do
        it 'renders the variant' do
          expect(rendered_component).to have_selector(".gl-alert-#{variant}")
          expect(rendered_component).to have_selector("[data-testid='#{described_class::ICONS[variant]}-icon']")
        end
      end
    end
  end
end

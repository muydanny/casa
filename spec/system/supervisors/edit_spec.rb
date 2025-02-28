require "rails_helper"

RSpec.describe "supervisors/edit", type: :system do
  let(:organization) { create(:casa_org) }

  context "logged in as an admin" do
    let(:user) { create(:casa_admin, casa_org: organization) }

    it "can edit supervisor by clicking on the edit link from the supervisors list page" do
      supervisor_name = "Leslie Knope"
      create(:supervisor, display_name: supervisor_name, casa_org: organization)
      sign_in user

      visit supervisors_path

      expect(page).to have_text(supervisor_name)

      within "#supervisors" do
        click_on "Edit"
      end

      expect(page).to have_text("Editing Supervisor")
    end

    it "can edit supervisor by clicking on the supervisor's name from the supervisors list page" do
      supervisor_name = "Leslie Knope"
      create(:supervisor, display_name: supervisor_name, casa_org: organization)
      sign_in user

      visit supervisors_path

      within "#supervisors" do
        click_on supervisor_name
      end

      expect(page).to have_text("Editing Supervisor")
    end

    it "can go to the supervisor edit page and see red message when there are no active volunteers" do
      supervisor = create :supervisor, casa_org: organization

      sign_in user

      visit edit_supervisor_path(supervisor)

      expect(page).to have_text("There are no active, unassigned volunteers available")
    end

    it "can go to the supervisor edit page and see invite and login info" do
      supervisor = create :supervisor, casa_org: organization

      sign_in user

      visit edit_supervisor_path(supervisor)

      expect(page).to have_text "Added to system "
      expect(page).to have_text "Invitation email sent never"
      expect(page).to have_text "Last logged in"
      expect(page).to have_text "Invitation accepted never"
      expect(page).to have_text "Password reset last sent never"
    end

    it "can deactivate a supervisor", js: true do
      supervisor = create :supervisor, casa_org: organization

      sign_in user
      visit edit_supervisor_path(supervisor)

      dismiss_confirm do
        click_on "Deactivate supervisor"
      end

      accept_confirm do
        click_on "Deactivate supervisor"
      end
      expect(page).to have_text("Supervisor was deactivated on")

      expect(supervisor.reload).not_to be_active
    end

    it "can activate a supervisor" do
      inactive_supervisor = create(:supervisor, casa_org_id: organization.id)
      inactive_supervisor.deactivate

      sign_in user

      visit edit_supervisor_path(inactive_supervisor)

      click_on "Activate supervisor"

      expect(page).not_to have_text("Supervisor was deactivated on")

      expect(inactive_supervisor.reload).to be_active
    end

    context "logged in as a supervisor" do
      let(:supervisor) { create(:supervisor) }
      it "can't deactivate a supervisor", js: true do
        supervisor2 = create :supervisor, casa_org: organization

        sign_in supervisor
        visit edit_supervisor_path(supervisor2)

        expect(page).to_not have_text("Deactivate supervisor")
      end

      it "can't activate a supervisor" do
        inactive_supervisor = create(:supervisor, casa_org_id: organization.id)
        inactive_supervisor.deactivate

        sign_in supervisor

        visit edit_supervisor_path(inactive_supervisor)

        expect(page).not_to have_text("Activate supervisor")
      end
    end

    context "when entering valid information" do
      it "updates the e-mail address successfully" do
        sign_in user
        supervisor = create(:supervisor)
        visit edit_supervisor_path(supervisor)

        expect {
          fill_in "supervisor_email", with: ""
          fill_in "supervisor_email", with: "new" + supervisor.email
          click_on "Submit"
          page.find ".header-flash > div"
          supervisor.reload
        }.to change { supervisor.email }.to "new" + supervisor.email
      end
    end

    context "when the email exists already" do
      let!(:existing_supervisor) { create(:supervisor) }

      it "responds with a notice" do
        sign_in user
        supervisor = create(:supervisor)
        visit edit_supervisor_path(supervisor)
        fill_in "supervisor_email", with: ""
        fill_in "supervisor_email", with: existing_supervisor.email
        click_on "Submit"

        within "#error_explanation" do
          expect(page).to have_content(/already been taken/i)
        end
      end
    end
  end

  context "logged in as a supervisor" do
    before do
      sign_in user
      visit edit_supervisor_path(supervisor)
    end

    context "when editing other supervisor" do
      let(:user) { create(:supervisor, casa_org: organization) }
      let(:supervisor) { create(:supervisor, casa_org: organization) }

      it "sees red message when there are no active volunteers" do
        expect(page).to have_text("There are no active, unassigned volunteers available")
      end

      it "does not have a submit button" do
        expect(page).not_to have_selector(:link_or_button, "Submit")
      end
    end

    context "when editing own page" do
      let(:supervisor) { create(:supervisor, casa_org: organization) }
      let(:user) { supervisor }

      it "displays a submit button" do
        visit edit_supervisor_path(supervisor)

        expect(page).to have_selector(:link_or_button, "Submit")
      end

      it "sees last invite and login info" do
        expect(page).to have_text "Added to system "
        expect(page).to have_text "Invitation email sent never"
        expect(page).to have_text "Last logged in"
        expect(page).to have_text "Invitation accepted never"
        expect(page).to have_text "Password reset last sent never"
      end

      context "when no volunteers exist" do
        let!(:volunteer_1) { create(:volunteer, display_name: "AAA", casa_org: organization) }

        it "does not error out when adding non-existent volunteer" do
          visit edit_supervisor_path(supervisor)
          click_on "Assign Volunteer"
          click_on "Assign Volunteer"
          expect(page).to have_text("There are no active, unassigned volunteers available.")
        end
      end

      context "when there are assigned volunteers" do
        let(:supervisor) { create(:supervisor, :with_volunteers, casa_org: organization) }

        it "shows assigned volunteers" do
          visit edit_supervisor_path(supervisor)

          expect(page).to have_text "Assigned Volunteers"
          expect(page).to_not have_button("Include unassigned")
          supervisor.volunteers.each do |volunteer|
            expect(page).to have_text volunteer.email
          end
        end

        context "when there are previously unassigned volunteers" do
          let!(:unassigned_volunteer) { create(:supervisor_volunteer, :inactive, supervisor: supervisor).volunteer }

          it "does not show them by default" do
            visit edit_supervisor_path(supervisor)

            expect(page).to_not have_text unassigned_volunteer.email
            expect(page).to have_button("Include unassigned")

            click_on "Include unassigned"

            expect(page).to have_button("Hide unassigned")
            expect(page).to have_text("All Volunteers")
            expect(page).to have_text unassigned_volunteer.email
          end
        end
      end
    end
  end
end

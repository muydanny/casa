require "rails_helper"

RSpec.describe "/case_court_reports", type: :request do
  let(:volunteer) { create(:volunteer, :with_cases_and_contacts, :with_assigned_supervisor) }

  before do
    sign_in volunteer
  end

  # case_court_reports#index
  describe "GET /case_court_reports" do
    context "as volunteer" do
      it "can view 'Generate Court Report' page" do
        get case_court_reports_path
        expect(response).to be_successful
      end
    end
  end

  # case_court_reports#show
  describe "GET /case_court_reports/:id" do
    context "when a valid / existing case is sent" do
      let(:casa_case) { volunteer.casa_cases.first }

      before do
        Tempfile.create do |t|
          casa_case.court_reports.attach(
            io: File.open(t.path), filename: "#{casa_case.case_number}.docx"
          )
        end
        get case_court_report_path(casa_case.case_number, format: "docx")
      end

      it "send response as a .DOCX file" do
        expect(response.content_type).to eq Mime::Type.lookup_by_extension(:docx)
      end

      it "send response with a status :ok" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when an INVALID / non-existing case is sent" do
      let(:invalid_casa_case) { build_stubbed(:casa_case) }

      before do
        get case_court_report_path(invalid_casa_case.case_number, format: "docx")
      end

      it "redirects back to 'Generate Court Report' page" do
        expect(response).to redirect_to(case_court_reports_path)
        expect(response.content_type).to eq "text/html; charset=utf-8"

        follow_redirect!

        expect(response.content_type).to eq "text/html; charset=utf-8"
        expect(response.body).to match(/<h5 class="card-title"><strong>Generate Court Report<\/strong><\/h5>/)
        expect(response.request.flash.to_h).to have_key("alert")
        expect(response.body).to match(/<div class="alert alert-warning alert-dismissible fade show" role="alert">/)
        expect(response.body).to match(/is not found./)
      end
    end
  end

  # case_court_reports#generate
  describe "POST /case_court_reports" do
    context "when no custom template is set" do
      before do
        request_generate_court_report
      end

      context "when a valid / existing case is sent" do
        let(:casa_case) { volunteer.casa_cases.first }

        it "sends response as a JSON string" do
          expect(response.content_type).to eq("application/json; charset=utf-8")
          expect(JSON.parse(response.body)).to be_instance_of Hash
        end

        it "has keys ['link', 'status'] in JSON string" do
          body_hash = JSON.parse(response.body)

          expect(body_hash).to have_key "link"
          expect(body_hash).to have_key "status"
        end

        it "sends response with status :ok" do
          expect(response).to have_http_status(:ok)
        end

        it "contains a link ending with .DOCX extension" do
          body_hash = JSON.parse(response.body)

          expect(body_hash["link"].length).to be > 0
          expect(body_hash["link"]).to end_with("#{casa_case.case_number}.docx")
        end

        it "uses the default template" do
          get JSON.parse(response.body)["link"]

          expect(get_docx_subfile_contents(response.body, "word/header3.xml")).to include("YOUR CASA ORG’S NUMBER")
        end
      end

      context "when an INVALID / non-existing case is sent" do
        let(:casa_case) { build_stubbed(:casa_case) }

        it "sends response as a JSON string" do
          expect(response.content_type).to eq("application/json; charset=utf-8")
          expect(JSON.parse(response.body)).to be_instance_of Hash
        end

        it "has keys ['link','status','error_messages'] in JSON string" do
          body_hash = JSON.parse(response.body)

          expect(body_hash).to have_key "link"
          expect(body_hash).to have_key "status"
          expect(body_hash).to have_key "error_messages"
        end

        it "sends response with status :not_found" do
          expect(response).to have_http_status(:not_found)
        end

        it "contains a empty link" do
          body_hash = JSON.parse(response.body)

          expect(body_hash["link"].length).to be 0
        end

        it "contains error messages with words 'not found'" do
          body_hash = JSON.parse(response.body)

          expect(body_hash["error_messages"].length).to be > 0
          expect(body_hash["error_messages"]).to match(/not found/)
        end
      end
    end

    context "when a custom template is set" do
      let(:casa_case) { volunteer.casa_cases.first }

      before do
        volunteer.casa_org.court_report_template.attach(io: File.new(Rails.root.join("app", "documents", "templates", "montgomery_report_template.docx")), filename: "montgomery_report_template.docx")

        request_generate_court_report
      end

      it "uses the custom template" do
        get JSON.parse(response.body)["link"]

        expect(get_docx_subfile_contents(response.body, "word/header2.xml")).to include("Voices for Children Montgomery")
      end
    end
  end

  private

  def request_generate_court_report
    post generate_case_court_reports_path,
      params: {
        case_court_report: {case_number: casa_case.case_number.to_s}
      },
      headers: {ACCEPT: "application/json"}
  end
end

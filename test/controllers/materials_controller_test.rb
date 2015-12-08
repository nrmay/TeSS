require 'test_helper'

class MaterialsControllerTest < ActionController::TestCase

  include Devise::TestHelpers

  setup do
    @material = materials(:good_material)
    @updated_material = {
        title: "New title",
        short_description: "New description",
        url: "http://new.url.com"
    }
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:materials)
  end

  test "should get new" do
    sign_in users(:regular_user)
    get :new
    assert_response :success
  end

  test "should create material" do
    sign_in users(:regular_user)
    assert_difference('Material.count') do
      post :create, material: { doi: @material.doi,  remote_created_date: @material.remote_created_date, remote_updated_date: @material.remote_updated_date, short_description: @material.short_description, title: @material.title, url: @material.url }
    end

    assert_redirected_to material_path(assigns(:material))
  end

  test "should show material" do
    get :show, id: @material
    assert_response :success
  end

  test "should get edit" do
    sign_in users(:regular_user)
    get :edit, id: @material
    assert_response :success
  end

  test "should update material" do
    sign_in users(:regular_user)
    # patch :update, id: @material, material: { doi: @material.doi,  remote_created_date: @material.remote_created_date,  remote_updated_date: @material.remote_updated_date, short_description: @material.short_description, title: @material.title, url: @material.url }
    patch :update, id: @material, material: @updated_material
    assert_redirected_to material_path(assigns(:material))
  end

  test "should destroy material" do
    sign_in users(:regular_user)
    assert_difference('Material.count', -1) do
      delete :destroy, id: @material
    end

    assert_redirected_to materials_path
  end

  test 'breadcrumbs for materials index' do
    get :index
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "li[class=active]", :text => /Materials/, :count => 1
    end
  end

  test 'breadcrumbs for showing material' do
    get :show, :id => @material
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "li", :text => /Materials/, :count => 1 do
        assert_select "a[href=?]", materials_url, :count => 1
      end
      assert_select "li[class=active]", :text => /#{@material.title}/, :count => 1
    end
  end

  test 'breadcrumbs for editing material' do
    sign_in users(:regular_user)
    get :edit, id: @material
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "li", :text => /Materials/, :count => 1 do
        assert_select "a[href=?]", materials_url, :count => 1
      end
      assert_select "li", :text => /#{@material.title}/, :count => 1 do
        assert_select "a[href=?]", material_url(@material), :count => 1
      end
      assert_select "li[class=active]", :text => /Edit/, :count => 1
    end
  end

  test 'breadcrumbs for creating new material' do
    sign_in users(:regular_user)
    get :new
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "li", :text => /Materials/, :count => 1 do
        assert_select "a[href=?]", materials_url, :count => 1
      end
      assert_select "li[class=active]", :text => /New/, :count => 1
    end
  end

  test "should find existing material" do
    post 'check_title', :format => :json,  :title => @material.title
    assert_response :success
    assert_equal(JSON.parse(response.body)['title'], @material.title)

  end

  test "should return nothing when material does't exist" do
    post 'check_title', :format => :json,  :title => 'This title should not exist'
    assert_response :success
    assert_equal(response.body, "")
  end

  # TODO: SOLR tests will not run on TRAVIS. Explore stratergy for testing solr
=begin
      test "should return matching materials" do
        get 'index', :format => :json, :q => 'training'
        assert_response :success
        assert response.body.size > 0
      end

      test "should return no matching materials" do
        get 'index', :format => :json, :q => 'kdfsajfklasdjfljsdfljdsfjncvmn'
        assert_response :success
        assert_equal(response.body,'[]')
        end
=end

end

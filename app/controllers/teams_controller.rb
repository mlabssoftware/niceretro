class TeamsController < ApplicationController
  respond_to :js, :html

  def index
    @teams = Team.order('name ASC')
    render layout: "pre_panel"
  end

  def new
    @team = Team.new
  end

  def edit
    @team = Team.find(params[:id])
  end

  def update
    @team = Team.find(params[:id])
    @team.update_attributes(teams_params)
  end

  def create
    @team = Team.new(teams_params)
    @team.save
  end

  private

  def teams_params
    params.require(:team).permit(:name)
  end
end

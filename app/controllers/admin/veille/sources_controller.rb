# frozen_string_literal: true

module Admin
  module Veille
    # CRUD minimal du registre des publications surveillées. Aucun
    # collecteur n'y est branché à ce stade.
    class SourcesController < BaseController
      before_action :set_source, only: %i[edit update destroy]

      def index
        @sources = ::Veille::Source.order(:name)
      end

      def new
        @source = ::Veille::Source.new(active: true)
      end

      def edit; end

      def create
        @source = ::Veille::Source.new(source_params)

        if @source.save
          redirect_to admin_veille_sources_path, notice: "Source créée."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @source.update(source_params)
          redirect_to admin_veille_sources_path, notice: "Source mise à jour."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        # dependent: :nullify — les candidats déjà importés sont conservés,
        # ils perdent seulement leur rattachement.
        @source.destroy
        redirect_to admin_veille_sources_path, notice: "Source supprimée."
      end

      private

      def set_source
        @source = ::Veille::Source.find(params[:id])
      end

      def source_params
        params.require(:source).permit(:name, :kind, :url, :active)
      end
    end
  end
end

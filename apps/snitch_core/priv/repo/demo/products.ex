defmodule Snitch.Demo.Product do
  alias NimbleCSV.RFC4180, as: CSV
  alias Snitch.Core.Tools.MultiTenancy.Repo

  alias Snitch.Data.Schema.{
    Image,
    OptionType,
    Product,
    ProductOptionValue,
    ShippingCategory,
    Taxon,
    Variant,
    Variation,
    VariationTheme
  }

  alias Snitch.Domain.Taxonomy
  alias Snitch.Tools.Helper.ImageUploader

  @base_path Application.app_dir(:snitch_core, "priv/repo/demo/demo_data")

  def create_products do
    product_path = Path.join(@base_path, "products.csv")

    product_path
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.filter(fn x -> x != "" end)
    |> Enum.each(fn [
                      name,
                      width,
                      height,
                      depth,
                      selling_price,
                      weight,
                      maximum_retail_price,
                      taxon,
                      image
                    ] ->
      width = Decimal.new(width)
      height = Decimal.new(height)
      depth = Decimal.new(depth)
      taxon = Repo.get_by(Taxon, name: taxon)
      variation_theme = Repo.get_by(VariationTheme, name: "size")
      theme_id = [to_string(variation_theme.id)]

      {:ok, updated_taxon} =
        Taxonomy.update_taxon(taxon, %{"variation_theme_ids" => theme_id, "image" => nil})

      selling_price = Money.new(selling_price, :USD)
      maximum_retail_price = Money.new(maximum_retail_price, :USD)

      product =
        create_product!(
          name,
          width,
          height,
          depth,
          selling_price,
          weight,
          maximum_retail_price,
          updated_taxon,
          image
        )

      associate_theme(product, variation_theme.id)
      create_variants(product)
    end)
  end

  defp associate_theme(product, theme_id) do
    params = %{
      theme_id: theme_id
    }

    Product.associate_theme_changeset(product, params) |> Repo.update!()
  end

  defp create_variants(product) do
    variant_path = Path.join(@base_path, "variants.csv")

    variant_path
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.filter(fn [
                        name,
                        width,
                        height,
                        depth,
                        selling_price,
                        weight,
                        maximum_retail_price,
                        taxon,
                        parent_sku,
                        image
                      ] ->
      parent_sku == product.name
    end)
    |> Enum.each(fn [
                      name,
                      width,
                      height,
                      depth,
                      selling_price,
                      weight,
                      maximum_retail_price,
                      taxon,
                      parent_sku,
                      image
                    ] ->
      width = Decimal.new(width)
      height = Decimal.new(height)
      depth = Decimal.new(depth)
      taxon = Repo.get_by(Taxon, name: taxon)
      selling_price = Money.new(selling_price, :USD)
      maximum_retail_price = Money.new(maximum_retail_price, :USD)

      variant =
        create_product!(
          name,
          width,
          height,
          depth,
          selling_price,
          weight,
          maximum_retail_price,
          taxon,
          image
        )

      create_product_option_value(variant, product)
      associate_product_variant(variant, product)
    end)
  end

  defp create_product!(
         name,
         width,
         height,
         depth,
         selling_price,
         weight,
         maximum_retail_price,
         taxon,
         image_name
       ) do
    light = Repo.get_by(ShippingCategory, name: "light")
    image = [create_image(image_name)]

    params = %{
      name: name,
      width: width,
      height: height,
      depth: depth,
      selling_price: selling_price,
      weight: weight,
      shipping_category_id: light.id,
      max_retail_price: maximum_retail_price,
      taxon_id: taxon.id
    }

    product = %Product{} |> Product.create_changeset(params) |> Repo.insert!()
    associate_image(product, image, image_name)
  end

  def create_product_option_value(variant, product) do
    option_type = Repo.get_by(OptionType, name: "size")

    params = %{
      value: "medium",
      display_name: "MEDIUM",
      option_type_id: option_type.id,
      product_id: variant.id
    }

    %ProductOptionValue{} |> ProductOptionValue.changeset(params) |> Repo.insert!()
  end

  defp associate_product_variant(variant, product) do
    %Variation{parent_product_id: product.id, child_product_id: variant.id} |> Repo.insert!()
  end

  defp create_image(image) do
    extension = Path.extname(image)
    name = Nanoid.generate() <> extension
    %Image{name: name, is_default: true} |> Repo.insert!()
  end

  defp associate_image(product, image, image_name) do
    uploaded_struct = upload_struct(image, product, image_name)
    upload_image(uploaded_struct, product)
    Product.associate_image_changeset(product, image) |> Repo.update!()
  end

  defp upload_struct([%Image{name: name} = image], product, image_name) do
    base_path = Application.app_dir(:snitch_core)

    %Plug.Upload{
      content_type: "image/jpeg",
      filename: name,
      path: "#{base_path}/priv/repo/demo/demo_data/static/product_images/#{image_name}"
    }
  end

  defp upload_image(%Plug.Upload{} = image, product) do
    case ImageModel.store(image, product) do
      {:ok, _} ->
        {:ok, product}

      _ ->
        {:error, "upload error"}
    end
  end
end

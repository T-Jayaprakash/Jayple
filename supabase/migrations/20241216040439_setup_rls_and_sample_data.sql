-- Location: supabase/migrations/20241216040439_setup_rls_and_sample_data.sql
-- Schema Analysis: Complete booking system exists with users, salons, services, bookings tables
-- Integration Type: RLS Setup and Mock Data Addition
-- Dependencies: Existing schema (users, salons, services, bookings, booking_status enum)

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users table (Pattern 1: Core User Table)
CREATE POLICY "users_manage_own_users"
ON public.users
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- RLS Policies for salons table (Pattern 2: Simple User Ownership)
CREATE POLICY "users_manage_own_salons"
ON public.salons
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- RLS Policies for services table (Pattern 2: Simple User Ownership via salon relationship)
CREATE OR REPLACE FUNCTION public.user_owns_salon_for_service(service_salon_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.salons s
    WHERE s.id = service_salon_id AND s.owner_id = auth.uid()
)
$$;

CREATE POLICY "users_manage_own_services"
ON public.services
FOR ALL
TO authenticated
USING (public.user_owns_salon_for_service(salon_id))
WITH CHECK (public.user_owns_salon_for_service(salon_id));

-- RLS Policies for bookings table (Pattern 2: Simple User Ownership)
CREATE POLICY "users_manage_own_bookings"
ON public.bookings
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Public read access for approved salons and services (Pattern 4: Public Read, Private Write)
CREATE POLICY "public_can_read_approved_salons"
ON public.salons
FOR SELECT
TO public
USING (is_approved = true);

CREATE POLICY "public_can_read_services"
ON public.services
FOR SELECT
TO public
USING (true);

-- Functions for automatic user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  );
  RETURN NEW;
END;
$$;

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Sample data for testing
DO $$
DECLARE
    customer_uuid UUID := gen_random_uuid();
    vendor_uuid UUID := gen_random_uuid();
    freelancer_uuid UUID := gen_random_uuid();
    salon1_uuid UUID := gen_random_uuid();
    salon2_uuid UUID := gen_random_uuid();
    salon3_uuid UUID := gen_random_uuid();
    service1_uuid UUID := gen_random_uuid();
    service2_uuid UUID := gen_random_uuid();
    service3_uuid UUID := gen_random_uuid();
    service4_uuid UUID := gen_random_uuid();
    service5_uuid UUID := gen_random_uuid();
    service6_uuid UUID := gen_random_uuid();
BEGIN
    -- Create auth users with required fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (customer_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'customer@jayple.com', crypt('customer123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Customer User", "role": "customer"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, '+91 9876543210', '', '', null),
        (vendor_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'vendor@jayple.com', crypt('vendor123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Vendor User", "role": "vendor"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, '+91 9876543211', '', '', null),
        (freelancer_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'freelancer@jayple.com', crypt('freelancer123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Rajesh Kumar", "role": "freelancer"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, '+91 9876543212', '', '', null);

    -- Insert sample salons
    INSERT INTO public.salons (id, name, description, address, latitude, longitude, image_url, owner_id, rating, is_approved, open_time, close_time) VALUES
        (salon1_uuid, 'Elite Hair Studio', 'Premium hair styling and grooming services with experienced professionals', 'T. Nagar, Chennai', 13.0827, 80.2707, 'https://images.pexels.com/photos/3993449/pexels-photo-3993449.jpeg?auto=compress&cs=tinysrgb&w=800', vendor_uuid, 4.8, true, '09:00:00', '20:00:00'),
        (salon2_uuid, 'Glamour Salon & Spa', 'Full-service beauty salon offering facial treatments, massage therapy, and styling', 'Anna Nagar, Chennai', 13.0850, 80.2101, 'https://images.pexels.com/photos/3992876/pexels-photo-3992876.jpeg?auto=compress&cs=tinysrgb&w=800', vendor_uuid, 4.6, true, '10:00:00', '21:00:00'),
        (salon3_uuid, 'Royal Cuts Barbershop', 'Traditional barbershop specializing in mens haircuts, beard trimming, and grooming', 'Velachery, Chennai', 12.9755, 80.2201, 'https://images.pexels.com/photos/1813272/pexels-photo-1813272.jpeg?auto=compress&cs=tinysrgb&w=800', vendor_uuid, 4.7, true, '08:00:00', '19:00:00');

    -- Insert sample services
    INSERT INTO public.services (id, name, price, duration_minutes, image_url, salon_id) VALUES
        (service1_uuid, 'Premium Haircut & Styling', 299, 45, 'https://images.pexels.com/photos/3993449/pexels-photo-3993449.jpeg?auto=compress&cs=tinysrgb&w=400', salon1_uuid),
        (service2_uuid, 'Hair Wash & Blow Dry', 199, 30, 'https://images.pexels.com/photos/3993436/pexels-photo-3993436.jpeg?auto=compress&cs=tinysrgb&w=400', salon1_uuid),
        (service3_uuid, 'Relaxing Facial Treatment', 399, 60, 'https://images.pexels.com/photos/3985322/pexels-photo-3985322.jpeg?auto=compress&cs=tinysrgb&w=400', salon2_uuid),
        (service4_uuid, 'Full Body Massage', 599, 90, 'https://images.pexels.com/photos/3757952/pexels-photo-3757952.jpeg?auto=compress&cs=tinysrgb&w=400', salon2_uuid),
        (service5_uuid, 'Classic Mens Haircut', 199, 30, 'https://images.pexels.com/photos/1813272/pexels-photo-1813272.jpeg?auto=compress&cs=tinysrgb&w=400', salon3_uuid),
        (service6_uuid, 'Beard Trim & Styling', 149, 20, 'https://images.pexels.com/photos/1570807/pexels-photo-1570807.jpeg?auto=compress&cs=tinysrgb&w=400', salon3_uuid);

    -- Insert sample bookings
    INSERT INTO public.bookings (user_id, salon_id, service_id, start_at, end_at, status, home_service) VALUES
        (customer_uuid, salon1_uuid, service1_uuid, (now() + interval '1 day')::timestamp, (now() + interval '1 day' + interval '45 minutes')::timestamp, 'confirmed'::public.booking_status, false),
        (customer_uuid, salon2_uuid, service3_uuid, (now() + interval '3 days')::timestamp, (now() + interval '3 days' + interval '60 minutes')::timestamp, 'pending'::public.booking_status, false);

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;